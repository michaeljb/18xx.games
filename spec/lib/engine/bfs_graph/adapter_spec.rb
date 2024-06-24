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
      it 'implements the public interface of Engine::Graph' do
        legacy_interface = Engine::Graph.public_instance_methods(false).sort
        bfs_interface = described_class.public_instance_methods(false).sort
        bfs_excluded = [:corp_graphs]
        expect(bfs_interface - bfs_excluded).to eq(legacy_interface)
      end

      describe '#route_info' do
        [
          ['1846', '10264', 603],
          ['1882', 'hs_sfemknko_1719112244', 33],
        ].each do |title, game_id, action|
          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action}" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.route_info(corporation)
              actual = adapter.route_info(corporation)
              expect(actual).to eq(expected)
            end
          end
        end
      end

      describe '#clear' do
        xit 'is implemented' do
        end
      end

      describe '#clear_graph_for' do
        xit 'is implemented' do
        end
      end

      describe '#can_token?' do
        [
          ['1861', '29683', 460],
          ['1867', '21268', 518],
          ['1867', '21268', 660], # a token placement is skipped due to insufficient funds

          # token is placed on the next action; B&O only tokenable via an
          # ability
          ['1846', '10264', 50],

          # MC places a second token in Mexico City via same_hex_allowed
          ['1822MX', 'home_and_ndem_auctioned_token_in_mexico_city', 1259],
          ['1822MX', 'home_and_ndem_auctioned_token_in_mexico_city', 1260],

          # LAIR uses a cheater token
          ['18 Los Angeles', '19984', 145],
          ['18 Los Angeles', '19984', 146],

        ].each do |title, game_id, action|
          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action} with default args" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.can_token?(corporation)
              actual = adapter.can_token?(corporation)
              expect(actual).to eq(expected)
            end
          end

          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action} with cheater tokens" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.can_token?(corporation, cheater: true)
              actual = adapter.can_token?(corporation, cheater: true)
              expect(actual).to eq(expected)
            end
          end

          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action} with same_hex_allowed" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.can_token?(corporation, same_hex_allowed: true)
              actual = adapter.can_token?(corporation, same_hex_allowed: true)
              expect(actual).to eq(expected)
            end
          end
        end
      end

      describe '#tokenable_cities' do
        [
          ['1861', '29683', 460], # token is placed on the next action
          ['1867', '21268', 518], # token is placed on the next action
          ['1867', '21268', 660], # a token placement is skipped due to insufficient funds
        ].each do |title, game_id, action|
          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action}" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.tokenable_cities(corporation).uniq.sort_by(&:hex)
              actual = adapter.tokenable_cities(corporation).sort_by(&:hex)
              expect(actual).to eq(expected)
            end
          end
        end
      end

      describe '#no_blocking?' do
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

      describe '#connected_hexes' do
        [
          ['1846', '10264', 147],
          ['1846', '10264', 563],
        ].each do |title, game_id, action|
          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action}" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.connected_hexes(corporation).transform_values(&:sort)
              actual = adapter.connected_hexes(corporation)

              expect(actual).to eq(expected)
            end
          end
        end
      end

      describe '#connected_nodes' do
        [
          ['1846', '10264', 147],
          ['1846', '10264', 563],
        ].each do |title, game_id, action|
          it "matches legacy for each corporation in #{title}/#{game_id} at action #{action}" do
            game = load_fixture(title, game_id, action)

            legacy_graph = Engine::Graph.new(game)
            adapter = Engine::BfsGraph::Adapter.new(game)

            game.corporations.each do |corporation|
              expected = legacy_graph.connected_nodes(corporation)
              actual = adapter.connected_nodes(corporation)

              expect(actual).to eq(expected)
            end
          end
        end
      end

      describe '#connected_paths' do
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

      describe '#reachable_hexes' do
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

      describe '#compute' do
        xit 'is implemented' do
        end
      end

    end
  end
end
