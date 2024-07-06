# frozen_string_literal: true

require_relative '../part/node'
require_relative 'edge'
require_relative 'fifo_queue'

module Engine
  module BfsGraph
    class Graph
      attr_reader :advanced, :route_info, :skipped, :last_processed,
                  :layable_hexes, :visited_hexes, :visited_nodes, :visited_paths,
                  :corporation, :visited

      def initialize(game, corporation, visualize: true, **opts)
        @game = game
        @corporation = corporation
        @opts = opts

        # visualization uses a little more memory and cycles to color each path
        # and node based on whether it's been processed/enqueued/etc
        @visualize = visualize

        @overlap = opts[:overlap] || :defer
        @skip_paths = opts[:skip_paths] || Set.new

        @home_as_token = opts[:home_as_token] || false
        @no_blocking = opts[:no_blocking] || false
        @skip_track = opts[:skip_track]

        @by_token = opts[:by_token]

        # all the opts from the existing Graph
        # TODO: use these in the computation logic
        @check_tokens = opts[:check_tokens]
        @check_regions = opts[:check_regions]

        init!
      end

      def viz_color_index(atom)
        return 3 if @queue.peek&.[](:atom) == atom
        return 2 if @visited.include?(atom) && enqueued?(atom)
        return 0 if @visited.include?(atom)
        return 1 if enqueued?(atom)
        return 9 if @overlapping_paths.include?(atom)

        12
      end

      # returns an array of arrays
      # - index in outer array correlates to color that will be used to display
      #   the paths in the inner array
      def viz_paths_for_display
        return [] unless @visualize
        return [] if @visualize_paths.empty?

        @advance_cache[:viz_paths_for_display] ||=
          begin
            by_color = @visualize_paths.group_by { |p| viz_color_index(p) }
            by_color.each_with_object(Array.new(by_color.keys.max) { [] }) do |(color, paths), obj|
              obj[color] = paths
            end
          end
      end

      def finished?
        @queue.empty? && @overlapping_paths.empty?
      end

      # clear atoms from the front of the queue that should be skipped
      def skip!
        return if finished?
        return unless (q_item = @queue.peek)

        atom = q_item[:atom]
        props = q_item[:props]

        #tokened = -> { @tokened.include?(atom) }
        skip_paths = -> { @skip_paths.include?(atom) }
        skip_track = -> { atom.path? && @skip_track == atom.track }
        already_visited = -> do
          @visited.include?(atom) &&
            @visited[atom][:from].include?(props[:from]) &&
            props[:dc_nodes].each { |dc_node, exits| exits < @visited[atom][:dc_nodes][dc_node] }
        end

        if [skip_paths, skip_track, already_visited].any?(&:call)
          dequeue
          @skipped += 1

          skip!
        end
      end

      # process one item off the queue--either reject the atom, or add it to
      # @visited and enqueue the next items
      def advance!
        return self if finished?

        if @queue.empty? && !@overlapping_paths.empty?
          # for each overlapping path that was deferred, create a graph that
          # skips the paths it overlaps with (and skips the other deferred
          # paths), and advance until it is finished or the path in question is
          # succesfully added
          @overlapping_paths.each do |path, props|
            edge = [path.a, path.b].find { |path_end| edge_wrapper(path_end) != props[:from] }
            opts = @opts.clone
            opts[:skip_paths] = @overlapping_paths.keys + path.hex.paths[edge.num] - [path]
            skip_graph = self.class.new(@game, @corporation, visualize: false, **opts)
            skip_graph.advance! until skip_graph.finished? ||
                                      (found = (skip_graph.visited.include?(path) &&
                                                skip_graph.visited[path][:from].include?(props[:from])))

            @skip_graphs_advanced += skip_graph.advanced

            if found
              enqueue(path, skip_overlap_check: true, overlap: :skip, **props)
            end
          end

          @overlapping_paths.clear
          @advanced += 1
          return self
        end

        @advance_cache.clear

        # get item from queue
        q_item = dequeue
        atom = q_item[:atom]
        props = q_item[:props]

        # "directly connected" nodes, i.e., cities or towns with a direct
        # pathway (chain of Engine::Part::Path instances) to this atom
        dc_nodes = props[:dc_nodes] || new_dc_nodes

        if !props[:skip_overlap_check] && path_overlaps?(atom, props[:from])
          case @overlap
          when :defer
            @overlapping_paths[atom][:from] = props[:from]
            dc_nodes.each { |dc_node, exits| @overlapping_paths[atom][:dc_nodes][dc_node].merge(exits) }
          when :skip

          end

          @advanced += 1
          skip!
          return self
        end

        # check for reasons to reject this node from the graph (count the rejects?)
        # - overlapping path
        # - invalid path (ie wrong way on a terminal path)
        # if (edge = path_revisiting_edge(atom, props[:from]))

        #   @visited_edges[edge]

        #   skip!
        #   return self
        # end

        is_starter = props[:from].is_a?(Engine::Token) || props[:from] == :home_as_token

        no_loop = is_starter || atom.path? || !!(find_tokened_without_loop(atom, dc_nodes))

        if no_loop
          # add atom to graph
          @visited[atom][:from].add(props[:from])
          dc_nodes.each { |dc_node, exits| @visited[atom][:dc_nodes][dc_node].merge(exits) }
          @visited_hexes.add(atom.hex)
          @layable_hexes[atom.hex]
        end

        # enqueue next atoms to visit
        case atom
        when Engine::Part::Junction
          junction = atom

          unless is_terminal_path?(props[:from])
            # enqueue next paths, avoid backtracking
            next_paths = junction.paths - [props[:from]]
            next_paths.each do |next_path|
              enqueue(next_path, from: junction, dc_nodes: dc_nodes.clone)
            end
          end

        when Engine::Part::Node
          node = atom
          @visited_nodes.add(node)
          @last_processed_is_node = true
          update_route_info!(node, dc_nodes)

          if no_loop &&
             !@tokened.include?(node) &&
             !is_terminal_path?(props[:from]) &&
             (@no_blocking || !node.blocks?(@corporation))

            # enqueue next paths
            node.paths.each do |next_path|
              # avoid backtracking
              next if next_path == props[:from]
              # some games have special offboard cities where tokened companies
              # pass through but others cannot
              next if next_path.terminal? && !node.tokened_by?(corporation)

              enqueue(next_path, from: node, dc_nodes: {node => Set.new(next_path.exits)})
            end
          end

        when Engine::Part::Path
          path = atom
          @visited_paths.add(path)
          @last_processed_is_node = false
          [path.a, path.b].each do |path_end|
            next if props[:from] == (path_end.edge? ? edge_wrapper(path_end) : path_end)

            case path_end
            when Engine::Part::Edge
              edge = edge_wrapper(path_end)
              hex = path_end.hex
              @visited_edges[edge][:dc_nodes].merge(dc_nodes)

              if !(path.terminal? && !props[:from].is_a?(Engine::Part::City))
                @layable_hexes[hex].add(edge[1])
                @layable_hexes[@game.hex_neighbor(hex, edge[1])].add(inverted(edge[1]))
              end

              path.connected_paths(path_end).each do |next_path|
                next if !path.tracks_match?(next_path, dual_ok: true)

                from_edge = next_path.edges.find { |e| e.num == inverted(edge[1]) }
                enqueue(next_path, from: edge_wrapper(from_edge), dc_nodes: dc_nodes.clone)
              end
            when Engine::Part::Node
              next_node = path_end
              enqueue(next_node, from: path, dc_nodes: dc_nodes.clone)
            when Engine::Part::Junction
              next_node = path_end
              enqueue(next_node, from: path, dc_nodes: dc_nodes.clone)
            end
          end
        end

        # note tokened/home nodes to easily keep them from being re-processed
        @tokened.add(atom) if is_starter

        @last_processed = atom
        @advanced += 1

        # skip any skippable items from the front of the queue at the end of
        # processing instead of the beginning so that in between calls to
        # `advance!`, `peek` will not return an element that is about to be
        # skipped; this is very helpful for visualization so that the right atom
        # has the "up next" color
        skip!

        self
      end

      def advance_to!(advance_to)
        advance! until @advanced >= advance_to || finished?
        self
      end

      def advance_to_end!
        advance! until finished?
        self
      end

      def jump_to!(advance_to)
        init! if @advanced > advance_to
        advance_to!(advance_to)
      end

      def reverse!
        jump_to!(@advanced - 1)
      end

      def reset!
        init!
        self
      end

      def last_processed_is_node?
        @last_processed_is_node
      end

      def inspect
        "<#{self.class.name}: #{@corporation&.name}>"
      end

      def edge_wrapper(edge)
        @edge_wrappers[[edge.hex.id, edge.num]] ||= [edge.hex.id, edge.num] # BfsGraph::Edge.new(edge)
      end

      def inverted(edge_num)
        (edge_num + 3) % 6
      end

      #private

      def init!
        # key: Engine::Part::Node or Engine::Part::Path
        # value: props hash
        #     - from: other atoms or `Engine::Part::Edge`s from which this atom
        #       has been visited
        #     - node_chains: array where each element is a node chain, a Set of
        #       Cities or Towns linking back to a token, used to prevent looping
        #       through a city or town multiple times while tracing connectivity
        #       (eventual TODO: make node chain an ordered set? could be useful
        #       for more quickly computing connectivity if this is converted to a
        #       general graph)
        @visited = Hash.new { |h, k| h[k] = {from: Set.new, dc_nodes: new_dc_nodes } }

        @overlapping_paths = Hash.new { |h, k| h[k] = {from: nil, dc_nodes: new_dc_nodes } }

        @edge_wrappers = {}
        @visited_edges = Hash.new { |h, k| h[k] = { dc_nodes: Set.new } }

        @visited_hexes = Set.new
        @visited_nodes = Set.new
        @visited_paths = Set.new
        # layable hexes are hexes where tiles can be laid/upgraded, i.e., visited
        # hexes as well as hexes with visited paths pointing at them; values are
        # edges where they connect to more layable hexes
        @layable_hexes = Hash.new { |h, k| h[k] = Set.new}

        # be able to show all paths which have been visited or just enqueued
        @visualize_paths = Set.new if @visualize

        @queue = BfsGraph::FifoQueue.new

        # hash set of which items are in the queue; value is an integer as they
        # can be enqueued from different directions (i.e., two different paths
        # leading into one city will both enqueue the city), so dequeuing can
        # decrement the value instead of removing them from the set entirely
        @enqueued_counts = Hash.new(0) if @visualize

        # note tokened nodes for efficient skipping; they never need to be added
        # to the graph when reached via any path because the graph originates
        # from them
        @tokened = Set.new

        # track how many steps have been processed in the graph; useful for
        # undoing
        @advanced = 0

        @skip_graphs_advanced = 0

        # track how many items were enqueued but were skipped at the end of an
        # advance! call as they were already processed
        @skipped = 0

        # avoid recomputing some state between `advance!` calls
        @advance_cache = {}

        @route_info = {}


        # TODO: refactor starters and reset!; if reset! is called for a
        # corporation with no tokens down, but later on their token is placed
        # and then the graph is evaluated, their queue is empty because of the
        # current implementation which initializes their queue in reset!

        # start with the corporation's placed tokens
        @corporation.tokens.each do |token|
          next unless token.city
          next if @by_token && @by_token.city != token.city

          enqueue(token.city, from: token)
        end

        if @home_as_token && !@corporation.tokens[0]&.city
          Array(@corporation.coordinates).each do |coord|
            hex = @game.hex_by_id(coord)

            if @corporation.city && (!@by_token || @by_token.city == @corporation.city)
              enqueue(hex.tile.cities[@corporation.city], from: :home_as_token)
            else
              hex.tile.city_towns.each do |city_town|
                next if @by_token && @by_token.city != city_town

                enqueue(city_town, from: :home_as_token)
              end
            end
          end
        end
      end

      def enqueue(atom, **props)
        @visualize_paths.add(atom) if @visualize && atom.is_a?(Engine::Part::Path)
        @queue.enqueue({atom: atom, props: props})
        @enqueued_counts[atom] += 1 if @visualize
        self
      end

      def enqueued?(atom)
        @enqueued_counts[atom].positive? if @visualize
      end

      def dequeue
        item = @queue.dequeue
        @enqueued_counts[item[:atom]] -= 1 if @visualize && item
        item
      end

      def include?(atom)
        @visited.include?(atom) || enqueued?(atom)
      end

      def update_route_info!(node, dc_nodes)
        @route_info[:route_available] ||=
          (connected_to_mandatory?(dc_nodes) && (node.route == :mandatory || node.route == :optional))

        @route_info[:route_train_purchase] ||=
          (connected_to_mandatory?(dc_nodes) && node.route == :mandatory)
      end

      def connected_to_mandatory?(dc_nodes)
        dc_nodes.any? { |dc_node, _| dc_node.route == :mandatory }
      end

      def is_terminal_path?(atom)
        atom.is_a?(Engine::Part::Path) && atom.terminal?
      end

      def path_revisiting_edge(path, from)
        return unless path.is_a?(Engine::Part::Path)

        next_edge = [path.a, path.b].find { |path_end| path_end != from }
        edge = edge_wrapper(next_edge)

        return edge if @visited_edges.include?(edge)
      end

      # key: node
      # value: set of exits
      def new_dc_nodes
        Hash.new { |h_, k_| h_[k_] = Set.new}
      end

      # DFS to trace a route back through connected cities to find a tokened
      # node, returning nil if one cannot be found
      def find_tokened_without_loop(target, dc_nodes, checked: Set.new)
        return unless target.is_a?(Engine::Part::Node)
        return if @tokened.include?(target)

        found_node = nil

        dc_nodes.any? do |dc_node, _edges|
          # TODO: check each edge correctly, might need to use incoming and
          # outgoing edges? then include the edge with the node inside of
          # `checked`
          next if checked.include?(dc_node)
          checked.add(dc_node)

          # found a loop
          next if dc_node == target

          # found the token, we're done!
          if @tokened.include?(dc_node)
            found_node = dc_node
            next true
          end

          found_node = find_tokened_without_loop(target, @visited[dc_node][:dc_nodes], checked: checked)
        end

        found_node
      end

      def path_overlaps?(atom, from)
        return false unless (path = atom).path?
        return false if @visited.include?(path)

        [path.a, path.b].any? do |path_end|
          next unless path_end.edge?
          next if (edge = edge_wrapper(path_end)) == from

          @visited_edges.include?(edge)
        end
      end
    end
  end
end
