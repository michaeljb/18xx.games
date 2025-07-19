# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        @_actions = actions.dup

        @actions = { 0 => Node.new({ 'type' => 'root', 'id' => 0 }) }

        @head = @actions[0] # Node
        @chat_head = nil # Node

        build_tree!(actions)
      end

      def [](id)
        @actions[id]
      end

      def clone
        Tree.new(@_actions)
      end

      def filtered_actions(head, include_chat: false)
        clone.actions_array_for!(head, include_chat: include_chat)
      end

      protected

      def actions_array_for!(head, include_chat: false)
        return [] if head.zero?
        return [] unless (action = @actions[head])

        orig_action = action
        if action.undo? || action.redo?
          # find "real action" head
          action = action.real_child
        elsif action.chat?
          # find nearest nonchat ancestor
          action.walk do |node, queue|
            if node.chat?
              queue.concat(node.parents.values)
            else
              action = node
              queue.clear
            end
          end
        end

        trunk = {}
        action.walk do |node, queue|
          trunk[node.id] = node
          queue << node.parent
        end

        if include_chat
          orig_action.walk do |node, queue|
            trunk[node.id] = node if node.chat?
            queue << node.parent
            queue << node.chat_parent

            # include chat messages that newer than the "real action" head, but
            # older than the given undo/redo head
            queue << node.parent.pending_undo if node.undo?
            if node.redo?
              queue << node.undo_parent
              queue << node.prev_redo if node.prev_redo
            end
          end
        end

        trunk.each do |_id, node|
          node.unlink_parents! { |parent| !trunk.include?(parent.id) }
          node.unlink_children! { |child| !trunk.include?(child.id) }
        end

        trunk.each do |_id, node|
          # TODO: can this be cleaned up by fixing build_tree! logic for chats
          # and stuff? maybe it would be most ideal for the latest link to be
          # the canonical one; or get rid of parent/child and just use
          # parent/children; maybe another enumerator for nonchat actions can work

          if !node.chat? && node.chat_parent
            node.unlink_parents! { |parent| parent != node.chat_parent }
            node.parent = node.chat_parent
          end
        end

        filtered = {}
        trunk[0].walk do |node, queue|
          filtered[node.id] = node.action_h unless node.root?

          node.children.values.each do |child|
            next if child.chat? && child.chat_parent && !filtered.include?(child.chat_parent.id)

            queue << child
          end
        end
        filtered.values
      end

      private

      # Builds tree from Array of raw actions. Resets and populates @actions,
      # @chats, and @active_undos.
      #
      # @param raw_actions [Hash] the actions passed to Engine::Game::Base
      # @returns [Hash<Integer => Node>]
      def build_tree!(raw_actions)
        prev_action_or_chat = @head

        raw_actions.each_with_object(@actions) do |raw_action, actions|
          action = Node.new(raw_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if actions.include?(id)

          actions[id] = action

          prev_action_or_chat.child = action

          if action.chat?
            @chat_head.child = action if @chat_head
            action.parent = prev_action_or_chat
            @chat_head = action
            prev_action_or_chat = action
            next
          end

          @head = prev_action_or_chat =
            case action.type
            when 'undo'
              @head.child = action
              undo_to_id = action.action_h['action_id'] || @head.parent&.id
              raise ActionTreeError, 'Cannot undo root action' if undo_to_id.nil?
              raise ActionTreeError, "Cannot undo to #{undo_to_id}" unless actions.include?(undo_to_id)

              action.child = actions[undo_to_id]
            when 'redo'
              undo_action = @head.pending_undo
              raise ActionTreeError, "Cannot find action to redo for #{@id}" if undo_action.nil? || !undo_action.undo?

              undo_action.child = action
              action.child = undo_action.parent
              if (prev_redo = @head.prev_redo)
                action.parent = prev_redo
              end

              undo_action.parent
            else
              @head.child = action
              action
            end
        end
      end
    end
  end
end
