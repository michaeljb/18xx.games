# frozen_string_literal: true

module Engine
  module Game
    class ActionTree
      attr_reader :active_undos

      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # id: Integer => action
        @actions = {}
        @chat_actions = {}

        # stack of Integer ids - allows "redo" to work
        @active_undos = []

        build_tree!(actions)
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
        prev_action_or_chat = nil
        prev_action = nil

        @actions = actions.each_with_object({}) do |original_action, action_tree|
          # dup to avoid bad mutations on the actual game state
          action = original_action.dup

          id = action['id']

          # initialize keys specific to being nodes in the action tree
          action['parent'] = nil
          action['trunk_child'] = nil
          action['children'] = []

          # always branch for chat actions, store them in a separate hash
          if action['type'] == 'message'
            @chat_actions[id] = action
            action['parent'] = prev_action_or_chat['id']
            prev_action_or_chat['children'] << id
            prev_action_or_chat['trunk_child'] = id if prev_action_or_chat['type'] == 'message'
            prev_action_or_chat = action
            next
          end

          action_tree[id] = action

          # trunk_child/parent connection with the previous action
          if prev_action && action['type'] != 'redo'
            action['parent'] = prev_action['id']
            prev_action['children'] << id
            prev_action['trunk_child'] = id
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

      # @param head [Integer] id of the latest action to include in the returned array
      # @param include_chat [TrueClass|FalseClass] whether chat messages appear
      #     in the returned array
      # @returns Array<action> - actions ready to process
      def filtered_actions(head, include_chat: false)
        actions = []

        action = @actions[head]
        until action.nil?
          actions << action
          action = @actions[action['parent']]
        end

        actions.reverse
      end
    end
  end
end
