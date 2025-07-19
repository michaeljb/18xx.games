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
          action = action.real_child
        elsif action.chat? && !include_chat
          action = action.ancestors_bfs.find { |node| !node.chat? }
        end

        action.unlink_children!

        # collect main actions leading to head
        trunk = {}
        action.ancestors_trunk(with_self: true).each do |node|
          trunk[node.id] = node
          node.parent.child = node unless node.root?
        end

        # collect most recent chat prior to head and all earlier chats
        if include_chat
          # nearest_chat = orig_action.ancestors_bfs(with_self: true).find(&:chat?)
          nearest_chat = orig_action.ancestors_trunk(with_self: true).lazy
                           .find.filter_map(&:chat_parent).force.first
          if nearest_chat
            nearest_chat.ancestors_chat(with_self: true).each do |node|
              trunk[node.id] = node
            end
          end
        end

        trunk.each do |_id, node|
          node.unlink_parents! { |parent| !trunk.include?(parent.id) }
          node.unlink_children! { |child| !trunk.include?(child.id) }

          # binding.pry if head == 6 && node.id == 4

          if node.chat?
            if node.nonchat_parent
              node.unlink_parents! { |parent| parent != node.nonchat_parent }
              node.parent = node.nonchat_parent
            end
          else
            if node.chat_parent
              node.unlink_parents! { |parent| parent != node.chat_parent }
              node.parent = node.chat_parent
            end
          end
        end

        # TODO: pathfind from root to head, picking up chats sensibly along
        # the way

        # start at root
        # if multiple actions, prefer the chat?

          # @chats.each do |id|
          #   chat = @actions[id]
          #   next if trunk.include?(id) || chat.parent&.chat?

          #   chat.for_self_and_descendants { |node| trunk[node.id] = node }
          #   ancestor = chat.find_ancestor(default: root) { |node| trunk.include?(node.id) }
          #   next_nonchat_action = ancestor.trunk_descendants.find { |node| !node.chat? }

          #   if next_nonchat_action
          #     next_nonchat_action.parent.child = chat
          #     last_chat = chat.find_head
          #     last_chat.child = next_nonchat_action
          #   else
          #     ancestor.find_head.child = chat
          #   end
          # end

        filtered = []
        trunk[0].descendants_trunk.each do |node|
          raise ActionTreeError, 'Found chat in final trunk, but should be skipping chat' if node.chat? && !include_chat

          filtered << node.action_h
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
        prev_action_or_chat = @head

        raw_actions.each_with_object(@actions) do |raw_action, actions|
          action = Node.new(raw_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if actions.include?(id)

          actions[id] = action

          action.parent = prev_action_or_chat

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
              undo_action = @head.undo_parent
              undo_action.child = action
              action.child = undo_action.parent
            else
              @head.child = action
              action
            end
        end
      end
    end
  end
end
