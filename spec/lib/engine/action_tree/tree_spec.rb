# frozen_string_literal: true

require './spec/spec_helper'
require 'engine/action_tree/tree'

# @param fixture [String] "<title>/<id>" for a JSON file in fixtures/
# @param kwargs [Hash] forwarded to Engine::Game#load
# @returns [ActionTree] the tree to inspect for testing
def get_action_tree(fixture, **_kwargs)
  filename = File.join('public', 'fixtures', "#{fixture}.json")
  raise "#{filename} does not exist" unless File.exist?(filename)

  game = Engine::Game.load(filename).maybe_raise!
  game.action_tree
end

# Helper method for testing
# @param node [Engine::ActionTree::Node]
# @returns [Hash] Integer ID based info on the tree relations for the given node
def node_props(node)
  {
    parent: node.parent&.id,
    child: node.child&.id,
    children: node.children.map(&:id).sort,
  }
end

module Engine
  module ActionTree
    describe Tree do
      describe '#new' do
        it 'sets parents, children, and child' do
          tree = get_action_tree('1889/ActionTree1')

          # chat [root]
          expect(node_props(tree[1])).to eq({parent: nil, child: 2, children: [2]})

          # chat [head]
          expect(node_props(tree[2])).to eq({parent: 1, child: nil, children: []})

          # bid [root]
          expect(node_props(tree[3])).to eq({parent: nil, child: 4, children: [4, 5]})

          # chat [head]
          expect(node_props(tree[4])).to eq({parent: 3, child: nil, children: []})

          # end_game [head]
          expect(node_props(tree[5])).to eq({parent: 3, child: nil, children: []})
        end

        it 'throws an error if duplicate action IDs are found' do
          expect { get_action_tree('1889/ActionTree_duplicate_ids') }.to raise_error(Engine::ActionTreeError)
        end

        it 'sets parents, children, and child with undo and redo actions present' do
          tree = get_action_tree('1889/ActionTree2')

          # message [root]
          expect(node_props(tree[1])).to eq({parent: nil, child: nil, children: []})

          # bid [root]
          expect(node_props(tree[2])).to eq({parent: nil, child: 3, children: [3]})

          # bid
          expect(node_props(tree[3])).to eq({parent: 2, child: 8, children: [4, 8]})

          # bid (undone by action 7)
          expect(node_props(tree[4])).to eq({parent: 3, child: 7, children: [5, 7]})

          # bid (undone by action 6)
          expect(node_props(tree[5])).to eq({parent: 4, child: 6, children: [6]})

          # undo
          expect(node_props(tree[6])).to eq({parent: 5, child: nil, children: []})

          # undo
          expect(node_props(tree[7])).to eq({parent: 4, child: nil, children: []})

          # bid (undone by 9, redone by 10)
          expect(node_props(tree[8])).to eq({parent: 3, child: 11, children: [9, 11]})

          # undo (action_id: 2, undone by 10)
          expect(node_props(tree[9])).to eq({parent: 8, child: 10, children: [10]})

          # redo (undo 9, set head to 8)
          expect(node_props(tree[10])).to eq({parent: 9, child: nil, children: []})

          # bid
          expect(node_props(tree[11])).to eq({parent: 8, child: 12, children: [12]})

          # bid
          expect(node_props(tree[12])).to eq({parent: 11, child: 13, children: [13]})

          # bid
          expect(node_props(tree[13])).to eq({parent: 12, child: 14, children: [14]})

          # pass
          expect(node_props(tree[14])).to eq({parent: 13, child: 15, children: [15]})

          # par
          expect(node_props(tree[15])).to eq({parent: 14, child: 16, children: [16]})

          # program_buy_shares
          expect(node_props(tree[16])).to eq({parent: 15, child: 17, children: [17]})

          # par
          expect(node_props(tree[17])).to eq({parent: 16, child: 18, children: [18]})

          # pass (undone by 27)
          expect(node_props(tree[18])).to eq({parent: 17, child: 32, children: [19, 27, 32]})

          # buy_shares (undone by 26)
          expect(node_props(tree[19])).to eq({parent: 18, child: 26, children: [20, 23, 26]})

          # message
          expect(node_props(tree[20])).to eq({parent: 19, child: 21, children: [21]})

          # message
          expect(node_props(tree[21])).to eq({parent: 20, child: 22, children: [22]})

          # message
          expect(node_props(tree[22])).to eq({parent: 21, child: nil, children: []})

          # sell_shares (undone by 25)
          expect(node_props(tree[23])).to eq({parent: 19, child: 31, children: [24, 25, 31]})

          # message
          expect(node_props(tree[24])).to eq({parent: 23, child: nil, children: []})

          # undo (undone by 30)
          expect(node_props(tree[25])).to eq({parent: 23, child: 30, children: [30]})

          # undo (undone by 29)
          expect(node_props(tree[26])).to eq({parent: 19, child: 29, children: [29]})

          # undo (undone by 28)
          expect(node_props(tree[27])).to eq({parent: 18, child: 28, children: [28]})

          # redo (undo 27, set head to 18)
          expect(node_props(tree[28])).to eq({parent: 27, child: nil, children: []})

          # redo (undo 26, set head to 19)
          expect(node_props(tree[29])).to eq({parent: 26, child: nil, children: []})

          # redo (undo 25, set head to 23)
          expect(node_props(tree[30])).to eq({parent: 25, child: nil, children: []})

          # undo (action_id: 18)
          expect(node_props(tree[31])).to eq({parent: 23, child: nil, children: []})

          # buy_shares
          expect(node_props(tree[32])).to eq({parent: 18, child: 33, children: [33]})

          # program_buy_shares
          expect(node_props(tree[33])).to eq({parent: 32, child: 34, children: [34]})

          # program_buy_shares
          expect(node_props(tree[34])).to eq({parent: 33, child: 35, children: [35]})

          # pass
          expect(node_props(tree[35])).to eq({parent: 34, child: 36, children: [36]})

          # pass
          expect(node_props(tree[36])).to eq({parent: 35, child: 37, children: [37]})

          # pass
          expect(node_props(tree[37])).to eq({parent: 36, child: 38, children: [38]})

          # pass
          expect(node_props(tree[38])).to eq({parent: 37, child: 41, children: [39, 41]})

          # lay_tile (undone by 40)
          expect(node_props(tree[39])).to eq({parent: 38, child: 40, children: [40]})

          # undo
          expect(node_props(tree[40])).to eq({parent: 39, child: nil, children: []})

          # lay_tile
          expect(node_props(tree[41])).to eq({parent: 38, child: 42, children: [42]})

          # lay_tile
          expect(node_props(tree[42])).to eq({parent: 41, child: 43, children: [43]})

          # buy_train
          expect(node_props(tree[43])).to eq({parent: 42, child: 44, children: [44]})

          # buy_train
          expect(node_props(tree[44])).to eq({parent: 43, child: 45, children: [45]})

          # pass
          expect(node_props(tree[45])).to eq({parent: 44, child: 46, children: [46]})

          # buy_shares
          expect(node_props(tree[46])).to eq({parent: 45, child: 47, children: [47]})

          # buy_shares
          expect(node_props(tree[47])).to eq({parent: 46, child: 48, children: [48]})

          # pass
          expect(node_props(tree[48])).to eq({parent: 47, child: 49, children: [49]})

          # pass
          expect(node_props(tree[49])).to eq({parent: 48, child: 50, children: [50]})

          # pass
          expect(node_props(tree[50])).to eq({parent: 49, child: 51, children: [51]})

          # lay_tile
          expect(node_props(tree[51])).to eq({parent: 50, child: 52, children: [52]})

          # buy_train
          expect(node_props(tree[52])).to eq({parent: 51, child: 53, children: [53]})

          # buy_train
          expect(node_props(tree[53])).to eq({parent: 52, child: 54, children: [54]})

          # pass
          expect(node_props(tree[54])).to eq({parent: 53, child: 55, children: [55]})

          # lay_tile
          expect(node_props(tree[55])).to eq({parent: 54, child: 56, children: [56]})

          # run_routes
          expect(node_props(tree[56])).to eq({parent: 55, child: 57, children: [57]})

          # dividend
          expect(node_props(tree[57])).to eq({parent: 56, child: 58, children: [58]})

          # buy_train
          expect(node_props(tree[58])).to eq({parent: 57, child: 59, children: [59]})

          # buy_train
          expect(node_props(tree[59])).to eq({parent: 58, child: 60, children: [60]})

          # end_game [head]
          expect(node_props(tree[60])).to eq({parent: 59, child: nil, children: []})
        end
      end

      describe '#filtered_actions' do
        it 'excludes chats' do
          tree = get_action_tree('1889/ActionTree1')

          head = 4
          actions = tree.filtered_actions(head, include_chat: false)
          action_ids = actions.map { |a| a['id'] }

          expect(action_ids).to eq([3, 4])
        end

        it 'includes chats at root' do
          tree = get_action_tree('1889/ActionTree1')

          head = 4
          actions = tree.filtered_actions(head, include_chat: true)
          action_ids = actions.map { |a| a['id'] }

          expect(action_ids).to eq([1, 2, 3, 5, 4])
        end
      end
    end
  end
end
