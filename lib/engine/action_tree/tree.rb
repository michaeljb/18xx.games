# frozen_string_literal: true

require_relative 'node'

module Engine
  module ActionTree
    class Tree
      # @param actions [Hash] the actions passed to Engine::Game::Base
      def initialize(actions)
        @_actions = actions.dup

        @actions = {0 => Node.new({'type' => 'root', 'id' => 0})}
        # Integers
        @chats = Set.new

        # stack of Integer ids - allows "redo" to work
        @active_undos = []

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
        #
        # TODO: exceeeeept we want to keep the specified action if it's
        # undo/redo for the sake of collecting the intended chats? maybe not
        #since we do the timestamp filtering anyway
        if action.undo?
          action = action.undo_child
        elsif action.redo?
          action = action.redo_child
        end
        real_head = action.id

        # find nearest real action if excluding chat
        action = action.parent until action.root? || !action.chat? if !include_chat

        # update `child` links so that `action` is the trunk head
        trunk = {0 => @actions[0]}
        action.delete_children!
        until action.root?
          trunk[action.id] = action

          action.parent.child = action
          action = action.parent
        end
        root = action

        # insert chat messages into the doubly linked list
        if include_chat
          @chats.each do |id|
            chat = @actions[id]

            # this chat was already added to `trunk`, indicating `head`
            # points to a chat that was already added to `trunk`
            next if trunk.include?(id)

            # if chat's parent is a chat, nothing to do
            next if chat.parent&.chat?

            # find the latest ancestor of this chat that is in trunk
            ancestor = chat.parent

            ancestor = ancestor.parent until ancestor.nil? || ancestor&.root? || trunk.include?(ancestor.id)
            ancestor = root if ancestor.nil?

            # this chat is the new direct child of its trunk ancestor, or of
            # another chat_head descended from that ancestor
            next_action = ancestor.child unless ancestor.child&.chat?
            prior_chat = ancestor.children.values.find(&:chat?)
            new_parent =
              if prior_chat && (prior_chat != chat)
                prior_chat.find_head
              else
                ancestor
              end
             new_parent.child = chat
             trunk[id] = chat

            # go to end of chats, set next action as the child of the chats
            chat.find_head.child = next_action if next_action
          end
        end

        filtered = []
        action = root
        until (action = action.child).nil?
          # skip chats newer than head
          if !(action.chat? && (action.action_h['created_at'] > timestamp))
            # return unwrapped action hashes, not Node objects
            filtered << action.action_h
          end
        end
        filtered
      end

      private

      # Builds tree from Array of "raw" actions. Resets and populates @actions,
      # @chats, and @active_undos.
      #
      # @param actions [Hash] the actions passed to Engine::Game::Base
      # @returns [Hash]
      def build_tree!(actions)
        @chats.clear
        @active_undos.clear

        # hold reference for linking to parent; treat chat messages differently
        # from actions
        prev_action_or_chat = @actions[0]
        prev_action = @actions[0]

        actions.each_with_object(@actions) do |original_action, action_tree|
          action = Node.new(original_action)
          id = action.id
          raise ActionTreeError, "Duplicate action id found: #{id}" if action_tree.include?(id)

          action_tree[id] = action

          # always branch for chat actions
          if action.chat?
            @chats.add(id)
            if prev_action_or_chat.chat?
              prev_action_or_chat.child = action
            else
              action.parent = prev_action_or_chat
            end
            prev_action_or_chat = action
            next
          end

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
