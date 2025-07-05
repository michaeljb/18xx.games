# frozen_string_literal: true

module Engine
  module ActionTree
    class Node
      attr_reader :id, :type, :parent, :child, :undo_parents, :redo_parents

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
        @undo_parents = Set.new
        @redo_parents = Set.new
        @child = nil
        @children = Set.new
      end

      def inspect
        "<ActionTree::Node:id:#{@id};parent:#{@parent&.id};child:#{@child&.id};children:#{@children.map(&:id)}>"
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

      # Sets `@parent` to the given node. Adds `self` to the given node's
      # `@children`.
      #
      # @param node [Node]
      # @returns nil
      def parent=(node)
        set_parent(node)
        node.add_to_children(self)
        node
      end

      # Sets `@child` to the given node. Adds the given node to
      # `@children`. Sets `node.parent` to `self`
      #
      # @param node [Node]
      # @returns nil
      def child=(node)
        node.set_parent(self)
        set_child(node)
        node
      end

      def undo_child=(node)
        set_child(node)
        node.add_to_undo_parents(self)
        node
      end

      def redo_child=(node)
        set_child(node)
        node.add_to_redo_parents(self)
        node
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

      def add_to_undo_parents(node)
        @undo_parents.add(node)
      end

      def add_to_redo_parents(node)
        @redo_parents.add(node)
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
        node = @parent
        @parent = nil
        node
      end
    end
  end
end
