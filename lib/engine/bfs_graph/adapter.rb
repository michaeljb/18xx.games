# frozen_string_literal: true

require_relative '../graph'
require_relative 'graph'

module Engine
  module BfsGraph
    # Implements the public interface of Engine::Graph for incremental,
    # backwards-compatible replacement.
    #
    # Once Engine::Graph is deprecated and then properly replaced, it may make
    # sense to move some of this logic into BfsGraph::Graph, or it might make
    # more sense to refactor more of the client code to take advantage of
    # BfsGraph::Graph's features like lazy advancement.
    class Adapter
      attr_reader :corp_graphs

      def initialize(game, **opts)
        @game = game

        @corp_graphs = Hash.new { |h,k| h[k] = Engine::BfsGraph::Graph.new(@game, k, **opts) }

        @can_token = {}
        @tokenable_cities = {}
        @no_blocking = opts[:no_blocking] || false

        @opts = opts
      end

      def clear
        @corp_graphs.each { |corp, _graph| clear_graph_for(corp) }
      end

      alias clear_graph_for_all clear

      def clear_graph_for(corporation)
        graph = @corp_graphs[corporation]
        graph.reset!

        @can_token.delete(corporation)
        @tokenable_cities.delete(corporation)
      end

      def route_info(corporation)
        graph = @corp_graphs[corporation]

        advance_for_route_info!(graph)
        graph.route_info.reject { |_k, v| v == false }
      end

      def can_token?(corporation, cheater: false, same_hex_allowed: false, tokens: corporation.tokens_by_type)
        return false if tokens.empty?

        graph = @corp_graphs[corporation]

        @can_token[corporation] ||= {}
        @can_token[corporation][[cheater, same_hex_allowed]] ||=
          begin
            can_token = lambda do |node|
              node.tokenable?(
                corporation,
                free: true,
                cheater: cheater,
                tokens: tokens,
                same_hex_allowed: same_hex_allowed,
              )
            end

            if graph.visited_nodes.any? { |node| can_token.call(node) }
              true
            else
              tokenable = false

              log_new_advance_calls(corporation, 'can_token?') do
                graph.advance! until graph.finished? ||
                                     (graph.last_processed_is_node? && (tokenable = can_token.call(graph.last_processed)))
              end

              tokenable || can_token_via_ability?(corporation)
            end
          end

        @can_token[corporation][[cheater, same_hex_allowed]]
      end

      def tokenable_cities(corporation)
        return @tokenable_cities[corporation] if @tokenable_cities.key?(corporation)

        graph = @corp_graphs[corporation]

        advance_to_end!(graph, 'tokenable_cities')
        cities = graph.visited_nodes.select do |node|
          node.tokenable?(corporation, free: true)
        end
        cities.concat(nodes_connected_via_ability(corporation).to_a)
        cities = cities.uniq.sort_by(&:hex)

        @tokenable_cities[corporation] = cities unless cities.empty?

        cities
      end

      def no_blocking?
        @no_blocking
      end

      # can lay/upgrade track on these
      def connected_hexes(corporation)
        graph = @corp_graphs[corporation]
        advance_to_end!(graph, 'connected_hexes')

        layable_hexes = graph.layable_hexes
        tokened_hexes(corporation).each { |h, e| layable_hexes[h].merge(e) }
        home_hexes(corporation).each { |h, e| layable_hexes[h].merge(e) } if @opts[:home_as_token]

        layable_hexes.transform_values(&:sort)
      end

      def connected_nodes(corporation)
        graph = @corp_graphs[corporation]
        advance_to_end!(graph, 'connected_nodes')

        visited_nodes = graph.visited_nodes
        visited_nodes.merge(nodes_connected_via_ability(corporation))
        visited_nodes.merge(home_hex_nodes(corporation)) if @opts[:home_as_token]

        visited_nodes.to_h { |n| [n, true] }
      end

      def connected_paths(corporation)
        graph = @corp_graphs[corporation]

        advance_to_end!(graph, 'connected_paths')
        graph.visited_paths.reject { |p| p.terminal? && p.junction }.to_h { |n| [n, true] }
      end

      def reachable_hexes(corporation)
        connected_paths(corporation).to_h { |p| [p.hex, true] }
      end

      # 1841 uses by_token stuff
      def connected_hexes_by_token(corporation, token)
        raise NotImplementedError
      end
      def connected_nodes_by_token(corporation, token)
        raise NotImplementedError
      end
      def connected_paths_by_token(corporation, token)
        raise NotImplementedError
      end
      def compute_by_token(corporation)
        raise NotImplementedError
      end

      def compute(corporation, routes_only: false, one_token: nil)
        graph = @corp_graphs[corporation]

        if routes_only
          advance_for_route_info!(graph)
        else
          advance_to_end!(graph, 'graph')
        end
      end

      def walk_calls(corporation)
        graph = @corp_graphs[corporation]

        advanced = graph.advanced
        skipped = graph.skipped

        {
          all: advanced + skipped,
          skipped: skipped,
          not_skipped: advanced,
        }
      end

      private

      # log how many new advance! calls were made, if any, when executing the
      # given block
      def log_new_advance_calls(corporation, computed)
        calls_before = walk_calls(corporation)[:not_skipped]

        yield

        calls_after = walk_calls(corporation)[:not_skipped]

        if calls_after > calls_before
          LOGGER.debug do
            "    BfsGraph::Adapter(#{corporation.name}, #{computed}) - #{walk_calls(corporation)[:not_skipped]} "\
            "advance! calls (#{walk_calls(corporation)[:skipped]} skip! calls)"
          end
        end
      end

      def advance_to_end!(graph, computed)
        log_new_advance_calls(graph.corporation, computed)  { graph.advance_to_end! }
      end

      def advance_for_route_info!(graph)
        log_new_advance_calls(graph.corporation, 'route_info') do
          graph.advance! until graph.finished? ||
                               graph.route_info == { route_available: true, route_train_purchase: true }
        end
      end

      def can_token_via_ability?(corporation)
        @game.abilities(corporation, :token) do |ability, c|
          next unless c == corporation # token ability must be activated
          next unless ability.teleport_price

          ability.hexes.each do |hex_id|
            @game.hex_by_id(hex_id).tile.cities.each do |node|
              return true
            end
          end
        end

        @game.abilities(corporation, :teleport) do |ability, owner|
          next unless owner == corporation # teleport ability must be activated

          ability.hexes.each do |hex_id|
            @game.hex_by_id(hex_id).tile.cities.each do |node|
              return true
            end
          end
        end

        false
      end

      def nodes_connected_via_ability(corporation)
        nodes = Set.new

        @game.abilities(corporation, :token) do |ability, c|
          next unless c == corporation # token ability must be activated
          next unless ability.teleport_price

          ability.hexes.each do |hex_id|
            @game.hex_by_id(hex_id).tile.cities.each do |node|
             nodes.add(node)
            end
          end
        end

        @game.abilities(corporation, :teleport) do |ability, owner|
          next unless owner == corporation # teleport ability must be activated

          ability.hexes.each do |hex_id|
            @game.hex_by_id(hex_id).tile.cities.each do |node|
             nodes.add(node)
            end
          end
        end

        nodes
      end

      # Engine:Graph#home_hexes adds all edges, even those without connecting
      # paths, to the home hexes' connections
      def home_hexes(corporation)
        Array(corporation.coordinates).to_h do |coord, home_hexes|
          hex = @game.hex_by_id(coord)
          [hex, Set.new(hex.neighbors.keys)]
        end
      end

      def home_hex_nodes(corporation)
        Array(corporation.coordinates).each_with_object(Set.new) do |coord, nodes|
          hex = @game.hex_by_id(coord)
          if corporation.city
            Array(corporation.city).each do |city_index|
              city = hex.tile.cities[city_index]
              nodes.add(city) if city
            end
          else
            nodes.merge(hex.tile.city_towns)
          end
        end
      end

      # TODO: incorporate legacy logic that uses
      # - @game.city_tokened_by?
      # - @game.for_graph_city_tokened_by?
      # - @opts[:check_tokens]
      # - @game.skip_token?
      def tokened_hexes(corporation)
        corporation.tokens.each_with_object({}) do |token, tokened_hexes|
          next unless token.city

          hex = token.city.hex
          tokened_hexes[hex] = Set.new(hex.neighbors.keys)
        end
      end
    end
  end
end
