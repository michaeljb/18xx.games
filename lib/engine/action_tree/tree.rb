# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # id: Integer => Node
        @actions = {0 => init_root}
        @chat_actions = {}

        # stack of Integer ids - allows "redo" to work
        @active_undos = []

        build_tree!(actions)
      end

      def [](id)
        @actions[id] || @chat_actions[id]
      end

      # Get the action with id equal to the given `head`, all of its ancestor
      # actions, and optionally all chat messages in the tree, returned in an
      # Array that can be processed.
      #
      # @param head [Integer] id of the latest action to include in the returned Array
      # @param include_chat [TrueClass|FalseClass] whether chat messages appear
      #     in the returned Array
      # @returns Array<Hash> - actions ready to process
      def filtered_actions(head, include_chat: false)
        filtered = {}

        # 0 is reserved for a special placeholder root node
        return [] if head == 0
        return [] unless (action = (@actions[head] || @chat_actions[head]))

        timestamp = action.action_h['created_at']

        # get off of undo/redo nodes, onto a real action
        if action.undo?
          action = action.undo_child
        elsif action.redo?
          action = action.redo_child
        end
        real_head = action.id

        # find nearest real action if excluding chat
        action = action.parent until action.root? || !action.chat? if !include_chat

        # make a new node; construct a graph separate from the main tree
        filtered_action = Node.new(action.action_h)
        filtered[action.id] = filtered_action

        # add ancestors of the action in this branch to `filtered`
        until action.root?
          filtered_parent = Node.new(action.parent.action_h)
          filtered[filtered_parent.id] = filtered_parent
          filtered_parent.child = filtered_action

          # continue up the `@actions` tree
          action = action.parent
          filtered_action = filtered[action.id]
        end
        root = filtered_action

        # insert chat messages into the doubly linked list
        if include_chat
          @chat_actions.each do |id, chat|
            # this chat was already added to `filtered`, indicating `head`
            # points to a chat that was already added to `filtered`
            next if filtered.include?(id)

            # if chat's parent is a chat, nothing to do
            next if chat.parent.chat?

            # find the latest ancestor of this chat that is in filtered
            action = chat.parent
            action = action.parent until action.root? || filtered.include?(action.id)
            action = filtered[action.id] if filtered.include?(action.id)

            # this chat is the new child
            next_action = action.child unless action.child&.chat?
            filtered_chat = Node.new(chat.action_h)
            filtered[id] = filtered_chat

            if (last_chat = action.children.values.find(&:chat?))
              last_chat = last_chat.child while last_chat.child
              last_chat.child = filtered_chat
            else
              action.child = filtered_chat
            end

            # go to end of chats, set next action as the child of the chats
            last_chat = filtered_chat

            until @chat_actions[last_chat.id].head? || last_chat.id == head
              chat_child = @chat_actions[last_chat.id].child
              filtered_chat_child = Node.new(chat_child.action_h)
              filtered[filtered_chat_child.id] = filtered_chat_child
              last_chat.child = filtered_chat_child
              last_chat = filtered_chat_child
            end

            last_chat.child = next_action if next_action
          end
        end

        actions = []
        action = root

        until (action = action.child).nil?
          # skip chats newer than head
          if !action.chat? || !(action.action_h['created_at'] > timestamp)
            # return unwrapped action hashes, not Node objects
            actions << action.action_h
          end
        end
        actions
      end

      private

      def init_root
        Node.new({'type' => 'root', 'id' => 0})
      end

      # Builds tree from Array of "raw" actions. Resets and populates @actions,
      # @chat_actions, and @active_undos.
      #
      # @param actions [Hash] the actions passed to Engine::Game::Base
      # @returns [Hash]
      def build_tree!(actions)
        @chat_actions.clear
        @active_undos.clear

        # hold reference for linking to parent; treat chat messages differently
        # from actions
        prev_action_or_chat = @actions[0]
        prev_action = @actions[0]

        actions.each_with_object(@actions) do |original_action, action_tree|
          action = Node.new(original_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if action_tree.include?(id) || @chat_actions.include?(id)

          # always branch for chat actions, store them in a separate hash
          if action.chat?
            @chat_actions[id] = action
            if prev_action_or_chat.chat?
              prev_action_or_chat.child = action
            else
              action.parent = prev_action_or_chat
            end
            prev_action_or_chat = action
            next
          end

          action_tree[id] = action

          # child/parent double link with the previous action
          prev_action.child = action if prev_action && !action.redo?

          prev_action_or_chat =
            prev_action =
            case action.type
            when 'undo'
              @active_undos << id
              LOGGER.debug { "undoing: #{prev_action.to_json}" }
              LOGGER.debug { "undo action: #{action.to_json}" }
              prev_id = action.action_h['action_id'] || prev_action.parent&.id
              action.undo_child = action_tree[prev_id] if prev_id
            when 'redo'
              undo_action = action_tree[@active_undos.pop]
              undo_action.child = action
              action.redo_child = undo_action.parent
            else
              @active_undos.clear
              action
            end
        end
      end
    end
  end
end
