# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # id: Integer => Node
        @actions = {}
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

        binding.pry

        return [] unless (action = (@actions[head] || @chat_actions[head]))

        # get off of undo/redo nodes, onto a real action
        if action.undo?
          action = action.undo_child
        elsif action.redo?
          action = action.redo_child
        end

        # find nearest real action if excluding chat
        if !include_chat
          action = action.parent until action.nil? || !action.chat?
        end
        return [] if action.nil?

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
            next if @chat_actions.include?(chat.parent&.id)

            # find the latest ancestor of this chat that is in filtered
            action = chat.parent
            action = action.parent until action.nil? || filtered.include?(action.id)
            # exclude chats newer than head
            next if action&.id == head

            if action.nil?
              # no ancestors of this chat are in filtered; make this chat a new root
              #
              # TODO: this should apply iff actions are done at the start of the game,
              # then some chats, then those actions are undone to root; need to
              # do some tracking down with undo_parents? need to rework this section
              next_action = root
              chat.delete_parent!
              root = chat
            else
              # this chat is the new child
              next_action = action.child
              action.child = chat
            end

            # go to end of chats, set next action as the child of the chats
            last_chat = chat
            until last_chat.head?
              last_chat = last_chat.child

              # don't take anything after head
              next if last_chat.id == id
            end
            last_chat.child = next_action
          end
        end

        # starting from the root, dump actions into an Array by way of 'child'
        # links
        actions = []
        action = root
        until action.nil?
          # return wrapped actions, not Node objects
          actions << action.action_h
          action = action.child
        end

        actions
      end

      private

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
        prev_action_or_chat = nil
        prev_action = nil

        @actions = actions.each_with_object({}) do |original_action, action_tree|
          action = Node.new(original_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if action_tree.include?(id) || @chat_actions.include?(id)

          # always branch for chat actions, store them in a separate hash
          if action.chat?
            @chat_actions[id] = action
            if prev_action_or_chat
              action.parent = prev_action_or_chat
              prev_action_or_chat.child = action if prev_action_or_chat.chat?
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
              prev_id = action.action_h['action_id'] || prev_action.parent.id
              action.undo_child = action_tree[prev_id]
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
