# frozen_string_literal: true

module Engine
  module ActionTree
    class Node
      attr_reader :id, :type, :parent, :child, :undo_child, :redo_child, :undo_parents, :redo_parents

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
        @children = {}

        @undo_parents = {}
        @redo_parents = {}
        @undo_child = nil
        @redo_child = nil
      end

      def inspect
        "<ActionTree::Node:id:#{@id};parent:#{@parent&.id};child:#{@child&.id};children:#{@children.keys}>"
      end

      def action_h
        @action_h.dup
      end

      def to_h
        h = {action: action_h}

        h[:parent] = @parent.id if @parent
        h[:child] = @child.id if @child
        h[:children] = @children.keys unless @children.empty?
        h[:undo_parents] = @undo_parents.keys unless @undo_parents.empty?
        h[:redo_parents] = @redo_parents.keys unless @redo_parents.empty?
        h[:undo_child] = @undo_child.id if @undo_child
        h[:redo_child] = @redo_child.id if @redo_child

        h
      end

      def to_json
        to_h.to_json
      end

      def children
        @children.dup
      end

      def root?
        @type == 'root'
      end

      def root
        root? ? self : parent.root
      end

      def head?
        @child == nil && @children.empty?
      end

      def find_head
        if head?
          self
        else
          binding.pry if child.nil?
          child.find_head
        end
        # head? ? self : child.find_head
      end

      # Sets `@parent` to the given node. Adds `self` to the given node's
      # `@children`.
      #
      # @param node [Node]
      # @returns node
      def parent=(node)
        set_parent(node)
        node.add_to_children(self)
        node
      end

      # Sets `@child` to the given node. Adds the given node to
      # `@children`. Sets `node.parent` to `self`
      #
      # @param node [Node]
      # @returns node
      def child=(node)
        set_child(node)
        node.set_parent(self)
        node
      end

      def undo_child=(node)
        set_undo_child(node)
        node.add_to_undo_parents(self)
        node
      end

      def redo_child=(node)
        set_redo_child(node)
        node.add_to_redo_parents(self)
        node
      end

      def delete_children!
        @children.values.each(&:delete_parent!)
        self
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

      def undo?
        @type == 'undo'
      end

      protected

      def set_parent(node)
        @parent = node
      end

      def add_to_undo_parents(node)
        @undo_parents[node.id] = node
      end

      def add_to_redo_parents(node)
        @redo_parents[node.id] = node
      end

      def add_to_children(node)
        @children[node.id] = node
      end

      def set_child(node)
        @child = node
        add_to_children(node)
      end

      def set_undo_child(node)
        @undo_child = node
        add_to_children(node)
      end

      def set_redo_child(node)
        @redo_child = node
        add_to_children(node)
      end

      def remove_child!(node)
        @children.delete(node.id)
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
