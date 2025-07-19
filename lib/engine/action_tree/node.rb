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

      def ancestors_bfs(with_self: false)
        BfsEnumerator.new(self, :parents, with_self: with_self)
      end

      def ancestors_trunk(with_self: false)
        TrunkEnumerator.new(self, :parent, with_self: with_self)
      end

      def ancestors_chat(with_self: false)
        TrunkEnumerator.new(self, :chat_parent, with_self: with_self)
      end

      def descendants_trunk(with_self: false)
        TrunkEnumerator.new(self, :child, with_self: with_self)
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

      class TrunkEnumerator
        include Enumerable

        def initialize(node, method, with_self: false)
          method_opts = %i[child parent chat_parent]
          raise ActionTreeError, "Node::TrunkEnumerator method must be one of #{method_opts}" unless method_opts.include?(method)

          @node = node
          @method = method
          @with_self = with_self
        end

        def each
          node = @node
          visited = Set.new([node.id])
          yield node if @with_self
          while (node = node.send(@method))
            raise ActionTreeError, "Found loop in Node::TrunkEnumerator(#{@method}) for #{@node}" if visited.include?(node.id)

            yield node
            visited.add(node.id)
          end
        end
      end

      class BfsEnumerator
        include Enumerable

        def initialize(node, method, with_self: false)
          @node = node
          @method = method
          @with_self = with_self
        end

        def each
          node = @node
          visited = Set.new([node.id])
          yield node if @with_self
          queue = node.send(@method).values
          # queue.shift is O(N)
          # TODO: implement deque class for O(1)
          while (node = queue.shift)
            raise ActionTreeError, "Found loop in Node::BfsEnumerator for #{@node}" if visited.include?(node.id)

            yield node
            visited.add(node.id)
            queue.concat(node.send(@method).values)
          end
        end
      end
    end
  end
end
