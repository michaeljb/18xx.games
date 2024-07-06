# frozen_string_literal: true

require './spec/spec_helper'

def load_fixture(game_title, game_id, action_id = nil)
  game_file = File.join(FIXTURES_DIR, game_title.to_s, game_id.to_s) + '.json'
  Engine::Game.load(game_file, at_action: action_id).maybe_raise!
end

def sanitize(data)
  case data
  when Hash
    case data.values[0]
    when Array
      data.transform_values(&:sort)
    else
      data
    end
  else
    data
  end
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
        {
          '1841' => {
            fixtures: {
              '132002' => [
                252, # start of phase 3
                326, # start of phase 4
                546, # start of phase 5
                939, # end of game; IFAI's E9 token graph has interesting overlapping_paths
              ],
            },
            graph_opts: [
              { check_tokens: true },
              { check_tokens: true, check_regions: true },
            ],
          },

          '1822MX' => {
            fixtures: {
              # MC places a second token in Mexico City via same_hex_allowed
              'home_and_ndem_auctioned_token_in_mexico_city': [1259, 1260],
            },
            graph_opts: [
              {home_as_token: true},
            ]
          },

          '1846' => {
            fixtures: {
              # token is placed on action 51; B&O only tokenable via an ability
              '10264': [50, 51, 147, 563, 603],
            },
          },

          '1858' => {
            fixtures: {
              '147489' => [
                118, # OR 1.2; caught lots of failures with initial impl here
                153, # SR 2
                156, # A floats, must choose home token
                157, # A chooses home token
                170, # OR 2.1; caught lots of failures with initial impl here
                198, # OR 2.2
                237, # OR 3.1
                283, # OR 3.2; caught lots of failures with initial impl here
                355, # OR 4.1
                429, # OR 4.2
                545, # OR 5.1
                628, # OR 5.2
                720, # OR 6.1
                787, # OR 6.2
                879, # OR 7.1
                928, # OR 7.2
                965, # game end
              ],
            },
            graph_opts: [
              {},
              { skip_track: :narrow },
              { skip_track: :broad },
            ],
          },

          # 1861 and 1867 are the only actual clients of tokenable_cities
          '1861' => {
            fixtures: {
              # token is placed on 461
              '29683': [460, 461],
            },
          },
          '1867' => {
            fixtures: {
              '21268': [660],
            },
          },

          '1882' => {
            fixtures: {
              # has variety of route_info
              'hs_sfemknko_1719112244': [33],
            },
          },

          '18 Los Angeles' => {
            fixtures: {
              # LAIR uses a cheater token
              '19984': [145, 146],
            },
          },

          # slow one
          # ['18GB', '151565', 650], # this passes

        }.each do |title, opts|

          describe title do
            opts[:fixtures].each do |game_id, actions|
              describe "fixture=#{game_id}" do
                before(:all) do
                  @game = load_fixture(title, game_id, 0)
                end

                actions.each do |action|
                  describe "action=#{action}" do
                    before(:each) do
                      @game.process_to_action(action)
                    end

                    (opts[:graph_opts] || [{}]).each do |graph_opts|
                      describe "graph_opts=#{graph_opts}" do
                        before(:all) do
                          @legacy_graph = Engine::Graph.new(@game, **graph_opts)
                          @adapter = Engine::BfsGraph::Adapter.new(@game, **graph_opts)
                        end
                        before(:each) do
                          @legacy_graph.clear_graph_for_all
                          @adapter.clear_graph_for_all
                        end

                        [
                          [:route_info, {}],
                          [:can_token?, {}],
                          [:can_token?, {cheater: true}],
                          [:can_token?, {same_hex_allowed: true}],
                          [:tokenable_cities, {}],
                          [:connected_hexes, {}],
                          [:connected_nodes, {}],
                          [:connected_paths, {}],
                          [:reachable_hexes, {}],
                        ].each do |method, kwargs|
                          it "#{method}(corporation, **#{kwargs})" do
                            aggregate_failures('corporations') do
                              @game.corporations.each do |corporation|
                                next if !corporation.floated? || corporation.closed?

                                expected = @legacy_graph.send(method, corporation, **kwargs)
                                actual = @adapter.send(method, corporation, **kwargs)

                                desc = "#{method} does not match for #{corporation.name} at "\
                                       "fixture/#{title}/#{game_id}?action=#{action}&graph"
                                expect(actual).to eq(expected), desc
                              end
                            end
                          end
                        end

                        [
                          :no_blocking?,
                        ].each do |method|
                          it method do
                            expected = @legacy_graph.send(method)
                            actual = @adapter.send(method)

                            desc = "#{method} does not match at "\
                                   "fixture/#{title}/#{game_id}?action=#{action}&graph"
                            expect(actual).to eq(expected), desc
                          end
                        end

                        [
                          :connected_hexes_by_token,
                          :connected_nodes_by_token,
                          :connected_paths_by_token,
                        ].each do |method|
                          it "#{method}(corporation, token/city)" do
                            aggregate_failures('corporations') do
                              @game.corporations.each do |corporation|
                                next if !corporation.floated? || corporation.closed?

                                corporation.tokens.each do |token|
                                  next unless token.used

                                  expected = sanitize(
                                    @legacy_graph.send(method, corporation, token.city))

                                  actual = sanitize(
                                    @adapter.send(method, corporation, token.city))

                                  desc = "#{method} does not match for #{corporation.name}, "\
                                         "token in #{token.city.hex.id} city ##{token.city.index} "\
                                         "at fixture/#{title}/#{game_id}?action=#{action}&graph"
                                  expect(actual).to eq(expected), desc
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
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
