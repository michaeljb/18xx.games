# frozen_string_literal: true

module Engine
  module Game
    class ActionTree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        # id: Integer => ActionNodeTree
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
        filtered = {}

        action = @actions[head]
        loop do
          id = action.id
          filtered[id] = action

          break if action.root?

          # set current action as the canonical child
          action.parent.child = action

          action = action.parent
        end
        root = action

        # insert chat messages into the doubly linked list
        if include_chat
          @chat_actions.each do |id, chat|
            # if chat's parent is a chat, nothing to do
            next if @chat_actions.include?(chat.parent&.id)

            # find the latest ancestor of this chat that is in filtered
            action = chat.parent
            action = action.parent until action.nil? || filtered.include?(action.id)

            if action.nil?
              # no ancestors of this chat are in filtered; make this chat a new root
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
            last_chat = last_chat.child until last_chat.head?
            last_chat.child = next_action
          end
        end

        # starting from the root, dump actions into an Array by way of 'child'
        # links
        actions = []
        action = root
        until action.nil?
          # return wrapped actions, not ActionNodeTree objects
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
          action = ActionTreeNode.new(original_action)
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

          prev_action_or_chat = prev_action =
            case action.type
            when 'undo'
              @active_undos << id
              prev_id = action.action_h['action_id'] || prev_action.parent.id
              action_tree[prev_id]
            when 'redo'
              undo_action = action_tree[@active_undos.pop]
              action.parent = undo_action
              action_tree[undo_action.parent.id]
            else
              @active_undos.clear
              action
            end
        end
      end
    end

    class ActionTreeNode
      attr_reader :id, :type, :parent, :child

      def initialize(action)
        @action_h =
          case action
          when Hash
            # dup to avoid mutations on the actual game state
            action.dup
          when Engine::Action::Base
            action.to_h
          end
        @id = @action_h['id']
        @type = @action_h['type']

        @parent = nil
        @child = nil
        @children = Set.new
      end

      def inspect
        "<ActionTreeNode: id:#{@id}, parent:#{@parent&.id}, child:#{@child&.id}, children:#{@children.map(&:id)}>"
      end

      def action_h
        @action_h.dup
      end

      def children
        @children.dup
      end

      def root?
        @parent == nil
      end

      def head?
        @child == nil && @children.empty?
      end

      def parent=(node)
        set_parent(node)
        node.add_to_children(self)
      end

      def child=(node)
        node.set_parent(self)
        set_child(node)
      end

      def delete_parent!
        @parent.remove_child!(self) if @parent
        remove_parent!
      end

      def chat?
        @type == 'message'
      end

      def redo?
        @type == 'redo'
      end

      protected

      def set_parent(node)
        @parent = node
      end

      def add_to_children(node)
        @children.add(node)
      end

      def set_child(node)
        @child = node
        add_to_children(node)
      end

      def remove_child!(node)
        @children.delete(node)
        @child = nil if @child == node
      end

      def remove_parent!
        @parent = nil
      end
    end
  end
end
