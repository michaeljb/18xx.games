# frozen_string_literal: true

require './spec/spec_helper'

def load_fixture(game_title, game_id, action_id = nil)
  game_file = File.join(FIXTURES_DIR, game_title.to_s, game_id.to_s) + '.json'
  Engine::Game.load(game_file, at_action: action_id).maybe_raise!
end

module Engine
  module BfsGraph
    describe Graph do
      describe '1867' do
        @title = '1867'
      end

      it 'does a thing' do
        game = load_fixture('1867', '21268', 518)
        corp = game.corporation_by_id('SLA')

        graph = described_class.new(game, corp, visualize: false)
        graph.advance_to!(31)

        queue = graph.instance_variable_get(:@queue)
        next_q_item = queue.peek

        path = next_q_item[:atom]
        from = next_q_item[:props][:from]
        dc_nodes = next_q_item[:props][:dc_nodes]

        expect(path.hex.id).to eq('F14')
        expect(path.exits).to eq([0, 5])

        hex_id, edge_num = from
        expect(hex_id).to eq('F14')
        expect(edge_num).to eq(5)

        peterborough = game.hex_by_id('G15').tile.cities[0]
        east_toronto = game.hex_by_id('F16').tile.cities[1]
        sudbury = game.hex_by_id('D8').tile.cities[0]

        visited = graph.instance_variable_get(:@visited)
        visited_edges = graph.instance_variable_get(:@visited_edges)

        expect(dc_nodes).to eq({peterborough => Set.new([2])})
        expect(visited[peterborough][:dc_nodes]).to eq({east_toronto => Set.new([4])})
        expect(visited[east_toronto][:dc_nodes]).to eq({sudbury => Set.new([5])})

        expect(graph.find_tokened_without_loop(peterborough, visited[peterborough][:dc_nodes])).to(
          eq(sudbury))

        edge = graph.edge_wrapper(game.hex_by_id('F14').tile.edges.find { |e| e.num.zero? })
        expect(visited_edges.include?(edge)).to eq(true)

        binding.pry
        expect(true).to eq(false)
      end
    end
  end
end
