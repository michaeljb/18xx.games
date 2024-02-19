# frozen_string_literal: true

module Engine
  module Part
    class Node < Base
      attr_accessor :lanes

      def clear!
        @paths = nil
        @exits = nil
      end

      def solo?
        @tile.nodes.one?
      end

      def paths
        @paths ||= @tile.paths.select { |p| p.nodes.any? { |n| n == self } }
      end

      def exits
        @exits ||= paths.flat_map(&:exits)
      end

      def rect?
        false
      end

      # Explore the paths and nodes reachable from this node
      #
      # visited: a hashset of visited Nodes
      # corporation: If set don't walk on adjacent nodes which are blocked for the passed corporation
      # visited_paths: a hashset of visited Paths
      # counter: a hash tracking edges and junctions to avoid reuse
      # skip_track: If passed, don't walk on track of that type (ie: :broad track for 1873)
      # converging_path: When true, some predecessor path was part of a converging switch
      # from: the path that lead to this node
      # visited_converging: track how this node was reached for proper deletion
      #   key: a node or path that was walked with converging or converging_path = true
      #   value: hashset of values that were `from` when the key was walked
      #
      # This method recursively bubbles up yielded values from nested Node::Walk and Path::Walk calls
      def walk(
        visited: {},
        corporation: nil,
        visited_paths: {},
        skip_paths: nil,
        counter: Hash.new(0),
        skip_track: nil,
        converging_path: true,
        from: nil,
        visited_converging: Hash.new { |h, k| h[k] = {} },
        &block
      )
        return if visited[self]
        return if visited_converging[self][from]

        visited[self] = true
        visited_converging[self][from] = true

        paths.each do |node_path|
          next if node_path.track == skip_track
          next if node_path.ignore?

          node_path.walk(
            visited: visited_paths,
            skip_paths: skip_paths,
            skip_track: skip_track,
            counter: counter,
            converging: converging_path,
            from: self,
            visited_converging: visited_converging,
          ) do |path, vp, ct, converging|
            ret = yield path, vp, visited
            next if ret == :abort
            next if path.terminal?

            path.nodes.each do |next_node|
              next if next_node == self
              next if corporation && next_node.blocks?(corporation)

              next_node.walk(
                visited: visited,
                counter: ct,
                corporation: corporation,
                visited_paths: vp,
                skip_track: skip_track,
                skip_paths: skip_paths,
                converging_path: converging_path || converging,
                from: path,
                visited_converging: visited_converging,
                &block
              )
            end
          end
        end

        visited.delete(self) if converging_path # && !(paths - visited_converging[self].keys).empty?
      end
    end
  end
end
