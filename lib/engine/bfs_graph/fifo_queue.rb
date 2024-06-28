module Engine
  module BfsGraph
    # FIFO Queue implementation using a linked list in an array. When an item is
    # dequeued from the front of the queue, its index in the array is added to a
    # stack of empty indices so they can be reused, and the array only grows in
    # size when necessary.
    #
    # Elements are stored in the queue as a tuple (Array) with a number
    # indicating the index of the element which comes after them in the queue.
    class FifoQueue
      include Enumerable

      NEXT = 0
      ELEMENT = 1

      def initialize(elements = [])
        @array = []

        # stack of locations in @array that are open for reuse
        @empty_indices = []

        # indices in @array
        @front = nil
        @back = nil

        elements.each { |e| self.enqueue(e) }
      end

      def empty?
        @front.nil?
      end

      def peek
        return if empty?

        @array[@front][ELEMENT]
      end

      def enqueue(element)
        unless (index = @empty_indices.pop)
          index = @array.size
          @array << nil
        end

        @array[index] = [nil, element]

        @front = index unless @front
        @array[@back][NEXT] = index if @back
        @back = index

        self
      end

      def dequeue
        return if empty?

        next_index, element = @array[@front]
        @array[@front] = nil
        @empty_indices << @front

        @front = next_index
        @back = nil if empty?

        element
      end

      # yield elements in queue order for Enumerable
      def each
        index = @front
        while index
          index, element = @array[index]
          yield element
        end
      end

      # dump the queue as actually represented in @array; to see the queue in
      # order, use `each`
      def to_s
        @array.to_s
      end

      def inspect
        "<#{self.class.name}>"
      end
    end
  end
end
