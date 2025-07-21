# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # TODO: deep copy of the action hashes?
        @raw_actions = actions.dup

        @actions = { 0 => Node.new({ 'type' => 'root', 'id' => 0 }) }

        @head = @actions[0] # Node; any kind of action
        @action_head = @head # Node; an action, no chat/undo/redo
        @chat_head = nil # Node; chat

        build_tree!(@raw_actions)
      end

      def inspect
        "<Engine::ActionTree::Tree>"
      end
      alias to_s inspect

      def clone
        Tree.new(@raw_actions)
      end

      def [](id)
        @actions[id]
      end

      def filtered_actions(head, include_chat: false)
        clone.actions_array_for!(head, include_chat: include_chat)
      end

      protected

      def actions_array_for!(head, include_chat: false)
        return [] if head.zero?
        return [] unless (action = @actions[head])

        subtree = {}

        # find action_head, add it and its ancestors to subtree
        action_head =
          if action.undo? || action.redo?
            action.original_child
          elsif action.chat?
            action.tree_walk do |node, queue|
              if node.chat?
                queue.concat(node.original_parents)
              else
                queue.clear
                node
              end
            end
          else
            action
          end
        action_head.tree_walk do |node, queue|
          subtree[node.id] = node
          queue << node.parent
        end

        if include_chat
          close_chat_ancestors = Hash.new { |h, k| h[k] = Set.new }

          find_close_chats = lambda do |action_node|
            action_node.tree_walk do |node, queue|
              next if subtree.include?(node.id) && action_node != node

              if node.chat?
                close_chat_ancestors[action_node.id].add(node.id)
              else
                queue.concat(node.original_parents)
              end
            end
          end

          find_close_chats.call(action) if action != action_head
          action_head.tree_walk do |node, queue|
            find_close_chats.call(node)
            queue << node.parent
          end

          chat_head = nil
          close_chat_ancestors.each do |node_id, chat_ids|
            node = trunk[node_id]
            next if chat_ids.include?(node.chat_parent.id)

            # TODO: test this
            nearest_chat = @actions[chat_ids.first].tree_walk do |node, queue|
              if !chat_ids.include?(node.id)
                queue.clear
                next
              end
              queue << node.chat_child
              node
            end
            nearest_chat.child = node
            chat_head = nearest_chat if chat_head.nil?
          end

          chat_head.tree_walk do |node, queue|
            subtree[node.id] = node
            queue << node.chat_parent
          end
        end


        subtree.each do |_id, node|
          # prune links to nodes outside of the subtree
          node.unlink_parents! { |parent| !subtree.include?(parent.id) }
          node.unlink_children! { |child| !subtree.include?(child.id) }

          # simplify child links to chats
          if include_chat
            if node.children.count { |_id, child| child.chat? } > 1
              first_chat = node.children.values.find(&:chat?)
              node.unlink_children! { |child| child.chat? && child != first_chat }
            end
          end
        end

        # walk the pruned subtree to form the filtered_actions array with chats
        # interleaved correctly
        filtered = []
        subtree[0].tree_walk do |node, queue|
          filtered << node.action_h unless node.root?

          if node.chat?
            if node.nonchat_child || (node.chat_child && node.chat_child.parents.size > 1)
              queue << node.chat_child
            else
              queue.unshift(node.chat_child)
            end
          else
            if node.chat_child
              queue << node.chat_child
              queue << node.child
            else
              queue.unshift(node.child)
            end
          end
        end

        if filtered.size != subtree.size - 1
          raise ActionTreeError, "Expected to create array of size #{subtree.size - 1}, got #{filtered.size}"
        end

        filtered
      end

      private

      # Builds tree from Array of raw actions. Resets and populates @actions,
      # @chats, and @active_undos.
      #
      # @param raw_actions [Hash] the actions passed to Engine::Game::Base
      # @returns [Hash<Integer => Node>]
      def build_tree!(raw_actions)
        raw_actions.each_with_object(@actions) do |raw_action, actions|
          action = Node.new(raw_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if actions.include?(id)

          actions[id] = action
          case action.type
          when 'message'
            @chat_head&.child = action
            @action_head.child = action
            action.parent = @head
            @chat_head = action
            @head = action
          when 'undo'
            # binding.pry if id == 31

            undo_to_id = action.action_h['action_id'] || @action_head.parent&.id || @head.parent&.id
            undo_to = actions[undo_to_id]
            raise ActionTreeError, "Cannot undo to #{undo_to_id}" unless undo_to

            # TODO: new method to make the link, but without setting @parent
            action.parent = @head

            @action_head.child = action
            action.child = undo_to
            @action_head = undo_to
          when 'redo'
            undo_action = @action_head.pending_undo
            raise ActionTreeError, "Cannot find action to redo for #{action.id}" if undo_action.nil? || !undo_action.undo?

            action.parent = @head

            undo_action.child = action
            redo_to = undo_action.parent
            action.child = redo_to
            if (prev_redo = @action_head.prev_redo)
              action.parent = prev_redo
            end

            @action_head = redo_to
          else
            action.parent = @head
            # TODO: @undo_head for holding undo/redo actions?
            action.parent = @action_head.pending_undo if @action_head.pending_undo
            @action_head.child = action
            @action_head = action
          end

          @head = action
          action.freeze_original_links!
        end
      end
    end
  end
end
