module Engine
  module BfsGraph
    class Edge
      attr_reader :hex, :num

      def initialize(edge)
        @num = edge.num
        @hex = edge.hex
      end

      def inverted
        @inverted ||= (@num + 3) % 6
      end

      def inspect
        "<BfsGraph::Edge: hex:#{hex.name} num:#{num}>"
      end
    end
  end
end
