# frozen_string_literal: true

module Engine
  module ActionTree
    class Node
      attr_reader :id, :type, :parent, :parents, :child, :children

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
        @parents = {}

        @child = nil
        @children = {}
      end

      def inspect
        "<ActionTree::Node:id:#{@id};parent:#{@parent&.id};parents:#{@parents.keys};child:#{@child&.id};children:#{@children.keys}>"
      end
      alias to_s inspect

      def action_h
        @action_h.dup
      end

      def to_h
        h = { action: action_h }

        h[:parent] = @parent.id if @parent
        h[:parents] = @parents.keys unless @parents.empty?
        h[:child] = @child.id if @child
        h[:children] = @children.keys unless @children.empty?

        h
      end

      def to_json(*_args)
        to_h.to_json
      end

      def real_child
        if undo? || redo?
          @children.reverse_each.find { |_id, node| node.real_action? }[1]
        else
          @child
        end
      end

      def pending_undo
        _id, node = @parents.reverse_each.find { |_id, node| !node.chat? && !node.redo? }
        node&.undo? ? node : nil
      end

      def undo_parent
        _id, node = @parents.reverse_each.find { |_id, node| node.undo? }
        node
      end

      # an "active" redo
      def prev_redo
        _id, node = @parents.reverse_each.find { |_id, node| !node.chat? }
        node&.redo? ? node : nil
      end

      def chat_parent
        _id, node = @parents.find { |_id, node| node.chat? }
        node
      end

      def nonchat_parent
        _id, node = @parents.find { |_id, node| !node.chat? }
        node
      end

      def parents
        @parents.dup
      end

      def root?
        @type == 'root'
      end

      def head?
        @child.nil?
      end

      def walk()
        visited = Set.new
        queue = [self]
        until queue.empty?
          node = queue.shift # O(N)
          next if node.nil?
          next if visited.include?(node.id)

          visited.add(node.id)
          yield(node, queue)
        end
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

      def unlink_children!
        @children.dup.each do |_id, node|
          next if block_given? && !yield(node)

          @child = nil if @child == node
          remove_child!(node)
          node.delete_parent!(self)
        end
        find_new_child!
        self
      end

      def unlink_parents!
        @parents.dup.each do |_id, node|
          next if block_given? && !yield(node)

          remove_parent!(node)
          delete_parent!(node)
        end
        find_new_parent!
        self
      end

      def delete_parent!(node)
        node ||= @parent
        node&.remove_child!(self)
        remove_parent!(node)
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

      def real_action?
        if @is_real_action.nil?
          @is_real_action = !chat? && !redo? && !undo?
        else
          @is_real_action
        end
      end

      protected

      def add_to_parents(node)
        raise ActionTreeError, "Cannot make #{node.id} its own parent" if node == self

        @parents[node.id] = node
      end

      def set_parent(node)
        raise ActionTreeError, "Cannot make #{node.id} its own parent" if node == self

        @parent = node if node.real_action? || (chat? && node.chat?)
        add_to_parents(node)
      end

      def remove_parent!(node)
        node ||= @parent
        @parent = nil if @parent == node
        @parents.delete(node&.id)
        find_new_parent!
        node
      end

      def add_to_children(node)
        raise ActionTreeError, "Cannot make #{node.id} its own child" if node == self

        @children[node.id] = node
      end

      def set_child(node)
        raise ActionTreeError, "Cannot make #{node.id} its own child" if node == self

        @child = node
        add_to_children(node)
      end

      def remove_child!(node)
        node ||= @chid
        @child = nil if @child == node
        @children.delete(node.id)
        find_new_child!
        node
      end

      private

      def find_new_parent!
        @parent = @parents[@parents.keys.last] if @parent.nil? && !@parents.empty?
        # _id, @parent = @parents.find { |_id, node| !node.chat? } if @parent.nil? && !@parents.empty?
      end

      def find_new_child!
        @child = @children[@children.keys.last] if @child.nil? && !@children.empty?
        # _id, @child = @children.find { |_id, node| !node.chat? } if @child.nil? && !@children.empty?
      end
    end
  end
end
