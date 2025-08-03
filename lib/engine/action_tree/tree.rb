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
        '<Engine::ActionTree::Tree>'
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

      # TODO: break this into smaller functions
      def actions_array_for!(head, include_chat: false)
        return [] if head.zero?
        return [] unless (head_node = @actions[head])

        subtree = {}

        # chat and undo/redo actions are never the action head
        action_head = find_action_head(head_node)

        # build the action trunk
        action_head.tree_walk do |node, queue|
          subtree[node.id] = node
          queue << node.parent
        end

        add_chat_branch_to_subtree!(head_node, action_head, subtree) if include_chat

        prune_subtree!(subtree)

        # TODO: separate function
        if include_chat
          lower_bound = upper_bound = target = nil
          reset_bounds = lambda do
            lower_bound = nil
            upper_bound = nil
            target = nil
          end

          (head_node.chat? ? head_node : action_head).tree_walk(check_visited: false) do |node, queue|
            state = {
              chat: node.chat?,
              child: node.nonchat_child,
              parent: node.nonchat_parent,
              lower_bound: lower_bound,
              upper_bound: upper_bound,
              target: target,
            }
            case state
            in {chat: true, lower_bound: nil, child: Node, parent: nil }
              lower_bound = node
              queue.unshift(node.chat_parent)
            in {chat: true, lower_bound: nil, } |
               {chat: true, lower_bound: Node, upper_bound: nil, child: nil, }
              queue.unshift(node.chat_parent)
            in {chat: true, lower_bound: Node, upper_bound: nil, child: Node, }
              upper_bound = node
              queue.unshift(node.chat_child)
            in {chat: true, parent: Node, lower_bound: Node, upper_bound: Node, }
              reset_bounds.call
            in {chat: true, parent: nil, lower_bound: Node, upper_bound: Node, }
              target = node
            in {chat: false, target: Node}
              target.parent = node
              reset_bounds.call
              queue << node.chat_parent
              queue << node.nonchat_parent
            in {chat: false, target: nil}
              queue << node.chat_parent
              queue << node.nonchat_parent
            else
              raise ActionTreeError, 'Unexpected state when fixing chat connections'
            end
          end
        end

        # walk the pruned subtree to form the filtered_actions array with chats
        # interleaved correctly
        filtered = []
        subtree[0].tree_walk do |node, queue|
          filtered << node.action_h unless node.root?

          # TODO: clean this up, possibly taking advantage of `next false` to
          # prevent a node from being marked as visited
          if node.chat?
            if node.nonchat_child || (node.chat_child && node.chat_child.parents.size > 1)
              queue << node.chat_child
            else
              queue.unshift(node.chat_child)
            end
          elsif node.chat_child
            queue << node.chat_child
            queue << node.child
          else
            queue.unshift(node.child)
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

      def find_action_head(action)
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
      end

      def closest_chat_ancestor(action_node, subtree)
        chat_ancestors = Set.new

        action_node.tree_walk do |node, queue|
          # walk through undos/etc, but not this action_node's parent from
          # the subtree
          next true if subtree.include?(node.id) && action_node != node

          if node.chat?
            chat_ancestors.add(node.id)
          else
            queue.concat(node.original_parents)
          end
        end

        @actions[chat_ancestors.first]&.tree_walk do |node, queue|
          unless chat_ancestors.include?(node.id)
            queue.clear
            next
          end
          queue << node.chat_child
          node
        end
      end

      # TODO: does this work for [chat, undo, chat, redo]?
      def add_chat_branch_to_subtree!(action, action_head, subtree)
        closest_chat_ancestors = {}
        closest_chat_ancestors[action] = closest_chat_ancestor(action, subtree) if action.redo? || action.undo?
        action_head.tree_walk do |node, queue|
          closest_chat_ancestors[node] = closest_chat_ancestor(node, subtree)
          queue << node.parent
        end

        @chat_head =
          if action.chat?
            action
          else
            latest_chat = nil
            closest_chat_ancestors.each do |node, chat|
              latest_chat ||= chat

              # add missing links from chat branch to the trunk
              chat&.child = node
            end

            latest_chat
          end

        @chat_head&.tree_walk do |node, queue|
          subtree[node.id] = node
          queue << node.chat_parent
        end

        closest_chat_ancestors
      end

      # prune links to nodes outside of the subtree, and don't let a real action
      # have more chat children than its first
      def prune_subtree!(subtree)
        subtree.each do |_id, node|
          node.unlink_parents! { |parent| !subtree.include?(parent.id) }
          node.unlink_children! { |child| !subtree.include?(child.id) }

          if node.children.count { |_id, child| child.chat? } > 1
            first_chat = node.children.values.find(&:chat?)
            node.unlink_children! { |child| child.chat? && child != first_chat }
          end
        end
      end
    end
  end
end
