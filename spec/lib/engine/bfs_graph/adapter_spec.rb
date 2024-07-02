# frozen_string_literal: true

require './spec/spec_helper'

def load_fixture(game_title, game_id, action_id = nil)
  game_file = File.join(FIXTURES_DIR, game_title.to_s, game_id.to_s) + '.json'
  Engine::Game.load(game_file, at_action: action_id).maybe_raise!
end

module Engine
  module BfsGraph
    describe Adapter do
      # rough check to make sure the Adapter is actually adapting everything it
      # needs to; finer details like method arguments are not enforced
      xit 'implements the public interface of Engine::Graph' do
        bfs_interface = described_class.public_instance_methods(false).sort
        bfs_excluded = [:corp_graphs]

        legacy_interface = Engine::Graph.public_instance_methods(false).sort
        # nothing external calls these, so they're private in the adapter
        legacy_excluded = [:home_hexes, :home_hex_nodes]

        expect(bfs_interface - bfs_excluded).to eq(legacy_interface - legacy_excluded)
      end

      describe 'return values match legacy' do
        # WARNING: should not add any of the really bad legacy cases that take
        # millions of `walk()` calls to this list since the legacy code is
        # executed here
        [
          # MC places a second token in Mexico City via same_hex_allowed
          ['1822MX', 'home_and_ndem_auctioned_token_in_mexico_city', 1259],
          ['1822MX', 'home_and_ndem_auctioned_token_in_mexico_city', 1260],

          ['1846', '10264', 50], # token is placed on action 51; B&O only tokenable via an ability
          ['1846', '10264', 147],
          ['1846', '10264', 563],
          ['1846', '10264', 603],

          # slow one
          # ['18GB', '151565', 650], # this passes

          # 1861 and 1867 are the only actual clients of tokenable_cities
          ['1861', '29683', 460], # token is placed on the next action
          ['1867', '21268', 518], # token is placed on the next action
          ['1867', '21268', 660], # a token placement is skipped due to insufficient funds

          ['1882', 'hs_sfemknko_1719112244', 33], # has variety of route_info

          # LAIR uses a cheater token
          ['18 Los Angeles', '19984', 145],
          ['18 Los Angeles', '19984', 146],

        ].each do |title, game_id, action|

          # append this describe string to "localhost:9292/" to load up the
          # fixture in your browser
          describe "fixture/#{title}/#{game_id}?action=#{action}" do
            before(:all) do
              @game = load_fixture(title, game_id, action)
              @legacy_graph = Engine::Graph.new(@game, **@game.class::GRAPH_OPTS)
              @adapter = Engine::BfsGraph::Adapter.new(@game, **@game.class::GRAPH_OPTS)
            end

            after(:each) do
              @legacy_graph.clear_graph_for_all
              @adapter.clear_graph_for_all
            end

            [
              [:route_info, [], {}],
              [:can_token?, [], {}],
              [:can_token?, [], {cheater: true}],
              [:can_token?, [], {same_hex_allowed: true}],
              [:tokenable_cities, [], {}],
              [:connected_hexes, [], {}],
              [:connected_nodes, [], {}],
              [:connected_paths, [], {}],
              [:reachable_hexes, [], {}],
            ].each do |method, args, kwargs|
              it "#{method}(corporation, *#{args}, **#{kwargs})" do
                aggregate_failures('corporations') do
                  @game.corporations.each do |corporation|
                    next if !corporation.floated? || corporation.closed?

                    expected = @legacy_graph.send(method, corporation, *args, **kwargs)
                    actual = @adapter.send(method, corporation, *args, **kwargs)

                    expect(actual).to eq(expected), "#{method} does not match for #{corporation.name}"
                  end
                end
              end
            end

            [
              [:no_blocking?, [], {}],
            ].each do |method, args, kwargs|
              it "#{method}(*#{args}, **#{kwargs})" do
                expected = @legacy_graph.send(method, *args, **kwargs)
                actual = @adapter.send(method, *args, **kwargs)
                expect(actual).to eq(expected), "#{method} does not match"
              end
            end
          end
        end
      end

      describe 'with no_blocking' do
        describe 'with home_as_token' do
          it "matches legacy for `G1848::Game#check_for_sydney_adelaide_connection` when false" do
            game = load_fixture('1848', '1848_hotseat_game', 336)

            legacy_graph = Engine::Graph.new(game, home_as_token: true, no_blocking: true)
            expect(legacy_graph.no_blocking?).to be(true)
            adapter = Engine::BfsGraph::Adapter.new(game, home_as_token: true, no_blocking: true)
            expect(adapter.no_blocking?).to be(true)

            expected = game.check_for_sydney_adelaide_connection(legacy_graph)
            actual = game.check_for_sydney_adelaide_connection(adapter)
            expect(actual).to eq(expected)
            expect(actual).to eq(false)
          end

          it "matches legacy for `G1848::Game#check_for_sydney_adelaide_connection` when true" do
            game = load_fixture('1848', '1848_hotseat_game', 337)

            legacy_graph = Engine::Graph.new(game, home_as_token: true, no_blocking: true)
            expect(legacy_graph.no_blocking?).to be(true)
            adapter = Engine::BfsGraph::Adapter.new(game, home_as_token: true, no_blocking: true)
            expect(adapter.no_blocking?).to be(true)

            expected = game.check_for_sydney_adelaide_connection(legacy_graph)
            actual = game.check_for_sydney_adelaide_connection(adapter)
            expect(actual).to eq(expected)
            expect(actual).to eq(true)
          end
        end

        it "matches legacy for `G1880::Game#check_for_foreign_investor_connection` when false" do
          game = load_fixture('1880', '1', 98)

          legacy_graph = Engine::Graph.new(game, no_blocking: true)
          expect(legacy_graph.no_blocking?).to be(true)
          adapter = Engine::BfsGraph::Adapter.new(game, no_blocking: true)
          expect(adapter.no_blocking?).to be(true)

          entity = game.current_entity

          expected = game.check_for_foreign_investor_connection(entity, legacy_graph)
          actual = game.check_for_foreign_investor_connection(entity, adapter)
          expect(actual).to eq(expected)
          expect(actual).to eq(false)
        end

        it "matches legacy for `G1880::Game#check_for_foreign_investor_connection` when true" do
          game = load_fixture('1880', '1', 126)

          legacy_graph = Engine::Graph.new(game, no_blocking: true)
          expect(legacy_graph.no_blocking?).to be(true)
          adapter = Engine::BfsGraph::Adapter.new(game, no_blocking: true)
          expect(adapter.no_blocking?).to be(true)

          entity = game.current_entity

          expected = game.check_for_foreign_investor_connection(entity, legacy_graph)
          actual = game.check_for_foreign_investor_connection(entity, adapter)
          expect(actual).to eq(expected)
          expect(actual).to eq(true)
        end
      end

      describe '#compute' do
        xit 'is implemented' do
        end
      end

      describe '#connected_hexes_by_token' do
        xit 'is implemented' do
        end
      end

      describe '#connected_nodes_by_token' do
        xit 'is implemented' do
        end
      end

      describe '#connected_paths_by_token' do
        xit 'is implemented' do
        end
      end

      describe '#compute_by_token' do
        xit 'is implemented' do
        end
      end

      describe '#home_hexes' do
        xit 'is implemented' do
        end
      end

      describe '#home_hex_nodes' do
        xit 'is implemented' do
        end
      end
    end
  end
end
