# frozen_string_literal: true

module Engine
  module ActionTree
    class Node
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
