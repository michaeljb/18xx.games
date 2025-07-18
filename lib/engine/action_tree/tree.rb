# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        @_actions = actions.dup

        @actions = {0 => Node.new({'type' => 'root', 'id' => 0})}

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
        # 0 is reserved for a special placeholder root node
        return [] if head == 0

        # unknown action requested
        return [] unless (action = @actions[head])

        timestamp = action.action_h['created_at']

        # get off of undo/redo nodes, onto a "real" action
        if action.undo? || action.redo?
          orig_action = action
          action = action.real_child
        elsif action.chat? && !include_chat
          # TODO: find nearest real action when excluding chat
          #
          # old code for exlucding chat; probably should be `action.with_ancestors.find`
          #
          # action = action.find_ancestor { |node| !node.chat? || node.root? }
        end

        action.delete_children!

        # TODO: implement enumerators for ancestors/descendants with/without
        # self
        # https://blog.appsignal.com/2018/05/29/ruby-magic-enumerable-and-enumerator.html#implementing-each

        trunk = {}
        root = action.trunk_ancestors(with_self: true).each do |node|
          trunk[node.id] = node
          node.parent.child = node unless node.root?
        end

        if include_chat

          # binding.pry if head == 4

          # find nearest chat; check for a chat parent on action and go up the
          # ancestry
          latest_chat = (action.trunk_ancestors(with_self: true).find do |node|
            node&.chat_parent
          end)&.chat_parent
          latest_chat.trunk_ancestors(with_self: true).each { |node| trunk[node.id] = node if node.chat? } if latest_chat

          # TODO: prune children so that only nodes in trunk remain
          #
          # then
          #
          # TODO: pathfind from root to head, picking up chats sensibly along
          # the way -- probably can't sort by timestamp due to eventual history changing

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
        end

        # binding.pry if head == 3

        filtered = []
        trunk[0].trunk_descendants.each do |node|
          if node.chat?
            next unless include_chat
            # skip chats newer than head
            next if node.action_h['created_at'] > timestamp
          end
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
            @chat_head = action
            prev_action_or_chat = action
            next
          end

          @head = prev_action_or_chat =
            case action.type
            when 'undo'
              @head.child = action
              undo_to_id = action.action_h['action_id'] || @head.parent&.id
              raise ActionTreeError, "Cannot undo root action" if undo_to_id.nil?
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
