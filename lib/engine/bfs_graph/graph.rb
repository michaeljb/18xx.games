# frozen_string_literal: true

require_relative '../part/node'
require_relative 'fifo_queue'

module Engine
  module BfsGraph
    class Graph
      attr_reader :advanced, :route_info, :skipped, :last_processed,
                  :layable_hexes, :visited_hexes, :visited_nodes, :visited_paths,
                  :corporation

      def initialize(game, corporation, visualize: true, **opts)
        @game = game
        @corporation = corporation

        # visualization uses a little more memory and cycles to color each path
        # and node based on whether it's been processed/enqueued/etc
        @visualize = visualize

        @home_as_token = opts[:home_as_token] || false
        @no_blocking = opts[:no_blocking] || false

        # all the opts from the existing Graph
        # TODO: use these in the computation logic
        @skip_track = opts[:skip_track]
        @check_tokens = opts[:check_tokens]
        @check_regions = opts[:check_regions]

        init!
      end

      def viz_color_index(atom)
        return 3 if @queue.peek&.[](:atom) == atom
        return 2 if @visited.include?(atom) && enqueued?(atom)
        return 0 if @visited.include?(atom)
        return 1 if enqueued?(atom)

        nil
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
        @queue.empty?
      end

      # clear atoms from the front of the queue that were already visited via
      # token, or via the same way they're being visited now
      def skip!
        return if finished?

        @skipped += 1

        q_item = @queue.peek
        atom = q_item[:atom]
        props = q_item[:props]

        if @tokened.include?(atom) ||
           (@visited.include?(atom) && @visited[atom][:from].include?(props[:from]))
          dequeue
          skip!
        end
      end

      # process one item off the queue--add the atom to @visited and enqueue the
      # next items
      def advance!
        return self if finished?

        @advance_cache.clear
        @advanced += 1

        # get item from queue
        q_item = dequeue
        atom = q_item[:atom]
        props = q_item[:props]
        node_chain = props[:node_chain] || Set.new

        # note tokened/home nodes for efficient skipping
        @tokened.add(atom) if props[:from].is_a?(Engine::Token) || props[:from] == :home_as_token

        # add atom to graph
        @visited[atom][:from].add(props[:from])
        @visited[atom][:node_chains] << node_chain
        @visited_hexes.add(atom.hex)
        @layable_hexes[atom.hex]

        # enqueue next atoms to visit
        case atom
        when Engine::Part::Junction
          junction = atom
          # enqueue next paths, avoid backtracking
          next_paths = junction.paths - [props[:from]]
          next_paths.each do |next_path|
            enqueue(next_path, from: junction, node_chain: node_chain.clone)
          end

        when Engine::Part::Node
          node = atom
          @visited_nodes.add(node)
          @last_processed_is_node = true
          update_route_info!(node)
          # stop if tokened out
          if @no_blocking || !node.blocks?(@corporation)
            # prevent looping back to this node
            next_node_chain = node_chain.clone
            next_node_chain.add(node)
            # enqueue next paths, avoid backtracking
            next_paths = node.paths - [props[:from]]
            next_paths.each do |next_path|
              enqueue(next_path, from: node, node_chain: next_node_chain)
            end
          end

        when Engine::Part::Path
          path = atom
          @visited_paths.add(path)
          @last_processed_is_node = false
          ([path.a, path.b] - [props[:from]]).each do |path_end|
            case path_end
            when Engine::Part::Edge
              edge = path_end

              inverted_edge = edge.hex.invert(edge.num)

              @layable_hexes[edge.hex].add(edge.num)
              @layable_hexes[@game.hex_neighbor(edge.hex, edge.num)].add(inverted_edge)

              path.connected_paths(edge).each do |next_path|
                next if !path.tracks_match?(next_path, dual_ok: true)

                from_edge = next_path.edges.find { |e| e.num == inverted_edge }
                enqueue(next_path, from: from_edge, node_chain: node_chain.clone)
              end
            when Engine::Part::Node, Engine::Part::Junction
              next_node = path_end
              enqueue(next_node, from: path, node_chain: node_chain.clone) unless node_chain.include?(next_node)
            end
          end
        end

        @last_processed = atom

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

      private

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
        @visited = Hash.new { |h, k| h[k] = {from: Set.new, node_chains: []} }

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

        # track how many items were enqueued but were skipped at the end of an
        # advance! call as they were already processed
        @skipped = 0

        # avoid recomputing some state between `advance!` calls
        @advance_cache = {}

        init_route_info!
        init_can_token!

        # start with the corporation's placed tokens
        @corporation.tokens.each do |token|
          next unless token.city

          enqueue(token.city, from: token)

          # TODO: move this to Adapter - legacy behavior: seems like this
          # shouldn't be a thing, it adds hex edges that aren't actually
          # connected to the token via a path to the city
          hex = token.city.hex
          hex.neighbors.each { |edge, _| @layable_hexes[hex].add(edge) }
        end

        if @home_as_token
          Array(@corporation.coordinates).each do |coord|
            hex = @game.hex_by_id(coord)
            hex.tile.city_towns.each do |city_town|
              enqueue(city_town, from: :home)

              # TODO: move this to Adapter - legacy behavior: seems like this
              # shouldn't be a thing, it adds hex edges that aren't actually
              # connected to any paths
              hex.neighbors.each { |edge, _| @layable_hexes[hex].add(edge) }

              # TODO: investigate 1858 and other home_as_token cases, might need to:
              # - if no city_towns, enqueue preprinted paths
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

      # check requirements for a runnable route, or a legal route that
      # necessitates owning a train
      def update_route_info!(node)
        return if @route_info[:route_train_purchase]

        @_node_count ||= Hash.new(0)
        @_node_count[node.route] += 1

        if @_node_count[:mandatory] > 1
          @route_info[:route_available] = true
          @route_info[:route_train_purchase] = true
        elsif @_node_count[:mandatory] == 1 && @_node_count[:optional].positive?
          @route_info[:route_available] = true
        end
      end

      def init_route_info!
        @route_info = {}
        @_node_count = nil
      end

      def init_can_token!
        @can_token = {}
      end
    end
  end
end
