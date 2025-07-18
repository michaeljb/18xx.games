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
        "<ActionTree::Node:#{@id}>"
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

      def children
        @children.dup
      end

      def real_child
        if action.undo? || action.redo?
          @children.reverse_each.find { |_id, node| !node.real_action? }
        else
          @child
        end
      end

      # find the latest parent that is not a redo or chat; if that parent is an
      # undo, return it, otherwise throw
      def undo_parent
        _id, node = @parents.reverse_each.find { |_id, node| !node.chat? && !node.redo? }
        raise ActionTreeError, "Cannot find undo_parent for #{@id}" if node.nil? || !node.undo?

        node
      end

      def chat_parent
        _id, node = @parents.find { |_id, node| node.chat? }
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

      def trunk_ancestors(with_self: false)
        TrunkEnumerator.new(self, :parent, with_self: with_self)
      end

      def trunk_descendants(with_self: false)
        TrunkEnumerator.new(self, :child, with_self: with_self)
      end

      # Sets `@parent` to the given node. Adds `self` to the given node's
      # `@children`.
      #
      # @param node [Node]
      # @returns node
      def parent=(node)
        delete_parent!(@parent)
        set_parent(node)
        node.add_to_children(self)
        node
      end

      # TODO
      # def parents<<(node)
      # end

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

      def delete_children!(&block)
        @children.each do |_id, node|
          next if block_given? && !block.call(node)

          node.delete_parent!(self)
        end

        _id, @child = @children.find { |_id, node| !node.chat? } if @child.nil? && !@children.empty?

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
        @parent = @parents[@parents.keys.last] unless @parents.empty?
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
        raise ActionTreeError, "Cannot remove #{node.id} from @children" unless @children.include?(node.id)

        @children.delete(node.id)
        @child = nil if @child == node
        node
      end

      private

      class TrunkEnumerator
        include Enumerable

        def initialize(node, method, with_self: false)
          raise ActionTreeError, "Node::TrunkEnumerator method must be one of :child or :parent" unless %i[child parent].include?(method)

          @node = node
          @method = method
          @with_self = with_self
        end

        def each(&block)
          node = @node
          yield node if @with_self
          while (node = node.send(@method))
            raise ActionTreeError, "Found loop in Node::TrunkEnumerator(#{@method}) for #{@node}" if node == @node

            yield node
          end
        end
      end
    end
  end
end
