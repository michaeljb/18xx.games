module Engine
  module ActionTree
    class Queue
      def initialize(*items, size: 16)
        clear(size)
        self << items
      end

      def empty?
        @size.zero?
      end

      def clear(size = nil)
        @array = Array.new(size || @array.size)
        @head = 0
        @tail = 0
        @size = 0
      end

      def <<(item_or_items)
        items = Array(item_or_items)
        rotate_and_resize! if items.size + @size > @array.size
        items.each do |item|
          @array[@tail] = item
          @size += 1
          inc_tail!
        end
      end

      def concat(items)
        self << items
      end

      def dequeue!
        item = @array[@head]
        @array[@head] = nil
        @size -= 1
        inc_head!
        item
      end

      def inspect
        index = @head
        ordered = []
        while index != @tail
          ordered << @array[index]
          index = (index + 1) % @array.size
        end
        ordered.inspect
      end
      alias to_s inspect

      private

      def rotate_and_resize!
        @array.rotate!(@head)
        @array[@array.size * 2] = nil
        @head = 0
        @tail = @size
      end

      def inc_head!
        @head =
          if @size.zero?
            0
          else
            @head + 1 % @array.size
          end
      end

      def inc_tail!
        @tail = @tail + 1
        @tail = @tail % @array.size if @head.zero?
        if @tail == @head
          rotate_and_resize!
          @tail = @size
        end
      end
    end
  end
end
