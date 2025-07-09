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
        binding.pry

        actions, chat_actions = clone_tree(@actions, @chat_actions)

        # 0 is reserved for a special placeholder root node
        return [] if head == 0

        # unknown action requested
        return [] unless (action = (actions[head] || chat_actions[head]))

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

        # update `child` links so that `action` is the trunk head
        trunk = {0 => actions[0]}
        until action.root?
          trunk[action.id] = action

          if action.parent.nil?
            binding.pry
          end

          action.parent.child = action
          action = action.parent
        end
        root = action

        # insert chat messages into the doubly linked list
        if include_chat
          chat_actions.each do |id, chat|
            # this chat was already added to `filtered`, indicating `head`
            # points to a chat that was already added to `filtered`
            next if actions.include?(id)

            # if chat's parent is a chat, nothing to do
            next if chat.parent.chat?

            # find the latest ancestor of this chat that is in trunk
            action = chat.parent
            action = action.parent until action.root? || trunk.include?(action.id)

            # this chat is the new direct child of its trunk ancestor, or of
            # another chat_head descended from that ancestor
            next_action = action.child unless action.child&.chat?
            if (chat_head = action.children.values.find(&:chat?))
              while chat_head.child
                chat_head = chat_head.child
                break if chat_head == chat
              end
              chat_head.child = chat unless chat_head == chat
            else
              action.child = chat
            end
            trunk[id] = chat

            # go to end of chats, set next action as the child of the chats
            chat_head = chat
            until chat_head.child.nil? # || chat_head.id == head
              trunk[chat_head.id] = chat_head
              chat_head = chat_head.child
            end
            chat_head.child = next_action if next_action
          end
        end

        filtered = []
        action = root
        until (action = action.child).nil?
          # skip chats newer than head
          if !action.chat? || !(action.action_h['created_at'] > timestamp)
            # return unwrapped action hashes, not Node objects
            filtered << action.action_h
          end
        end
        filtered
      end

      private

      def init_root
        Node.new({'type' => 'root', 'id' => 0})
      end

      # return new copies of actions and chat_actions so their parent/child
      # connections can be modified without mutating the originals
      def clone_tree(actions, chat_actions)
        # TODO: parent needs to be set explicitly, disregard children order,
        # or maybe just need to use undo/redo child instead?

        cloned = {}
        cloned_chat = {}

        # make copies of all the nodes
        actions.each do |id, action|
          cloned[id] = Node.new(action.action_h)
        end
        chat_actions.each do |id, action|
          cloned_chat[id] = Node.new(action.action_h)
        end

        # connect the nodes after they all exist
        actions.each do |id, action|
          action.children.each do |child_id, child|
            cloned_child = cloned[child_id] || cloned_chat[child_id]
            if action.child&.id == child_id
              cloned[id].child = cloned_child
            else
              cloned_child.parent = cloned[id]
            end
          end
        end
        cloned_chat.each do |id, action|
          action.children.each do |child_id, child|
            if action.child&.id == child_id
              cloned_chat[id].child = cloned_chat[child_id]
            else
              cloned_chat[child_id].parent = cloned_chat[id]
            end
          end
        end

        [cloned, cloned_chat]
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
