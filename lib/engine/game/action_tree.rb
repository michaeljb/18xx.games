# frozen_string_literal: true

module Engine
  module Game
    class ActionTree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # id: Integer => action
        @actions = {}
        @chat_actions = {}

        # stack of Integer ids - allows "redo" to work
        @active_undos = []

        build_tree!(actions)
      end

      def [](id)
        @actions[id] || @chat_actions[id]
      end

      # @param head [Integer] id of the latest action to include in the returned array
      # @param include_chat [TrueClass|FalseClass] whether chat messages appear
      #     in the returned array
      # @returns Array<action> - actions ready to process
      def filtered_actions(head, include_chat: false)
        require 'pry-byebug'
        binding.pry

        filtered = {}

        # collect actions from the head to root by way of 'parent' links, and
        # establish new 'child' links since other branches are ignored here,
        # creating a doubly linked list; use `.dup` to avoid mutations on
        # @actions
        action = @actions[head].dup
        loop do
          id = action['id']
          filtered[id] = action

          parent_id = action['parent']
          parent = @actions[parent_id].dup

          if parent.nil?
            # found the root, and it is the current value of `action`
            break
          else
            parent['child'] = id
            action = parent
          end
        end
        root = action

        if include_chat
          # insert chat messages into the doubly linked list
          @chat_actions.each do |id, chat|
            parent_id = chat['parent']

            # if chat's parent is a chat, nothing to do
            next if @chat_actions.include?(parent_id)

            # find the latest ancestor of this chat in filtered
            action = @actions[parent_id]
            until action.nil? || filtered.include?(action['id'])
              action = @actions[action['parent']]
            end

            if action.nil?
              # this chat is the new root
              next_action_id = root['child']
              root = chat
              chat['parent'] = nil
            else
              # this chat is the new child
              next_action_id = action['child']
              action['child'] = id
              chat['parent'] = action['id']
            end

            # go to end of chats, set next action as the child of the chats
            last_chat = chat
            until last_chat['child'].nil?
              last_chat = @chat_actions[last_chat['child']]
            end
            last_chat['child'] = next_action_id
            filtered[next_action_id]['parent'] = id
          end
        end

        # starting from the root, dump actions into an Array by way of 'child'
        # links
        actions = []
        action = root
        until action.nil? do
          actions << action
          child_id = action['child']
          action = filtered[child_id]
        end

        # return original versions of actions, without parent/child
        # modifications
        actions.map { |a| @actions[a['id']] || @chat_actions[a['id']] }
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
          # dup to avoid mutations on the actual game state
          action = original_action.dup

          id = action['id']

          # initialize keys specific to being nodes in the action tree
          action['parent'] = nil
          action['child'] = nil # the canonical/trunk action following this action
          action['children'] = [] # all children, including the one set as 'child'

          # always branch for chat actions, store them in a separate hash
          if action['type'] == 'message'
            @chat_actions[id] = action
            if prev_action_or_chat
              action['parent'] = prev_action_or_chat['id']
              prev_action_or_chat['children'] << id
              prev_action_or_chat['child'] = id if prev_action_or_chat['type'] == 'message'
            end
            prev_action_or_chat = action
            next
          end

          action_tree[id] = action

          # child/parent double link with the previous action
          if prev_action && action['type'] != 'redo'
            action['parent'] = prev_action['id']
            prev_action['children'] << id
            prev_action['child'] = id
          end

          prev_action_or_chat = prev_action =
            case action['type']
            when 'undo'
              @active_undos << id
              prev_id = action['action_id'] || prev_action['parent']
              action_tree[prev_id]
            when 'redo'
              undo_id = @active_undos.pop
              action['parent'] = undo_id
              undo_action = action_tree[undo_id]
              undo_action['children'] << id
              action_tree[undo_action['parent']]
            else
              @active_undos.clear
              action
            end
        end
      end
    end
  end
end
