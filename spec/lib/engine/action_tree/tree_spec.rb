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
    undo_parents: node.undo_parents.map(&:id).sort,
    redo_parents: node.redo_parents.map(&:id).sort,
  }
end

module Engine
  module ActionTree
    describe Tree do
      describe '#new' do
        it 'sets parents, children, and child' do
          tree = get_action_tree('1889/ActionTree1')

          # chat [root]
          expect(node_props(tree[1])).to eq({parent: nil, child: 2, children: [2], undo_parents: [], redo_parents: []})

          # chat [head]
          expect(node_props(tree[2])).to eq({parent: 1, child: nil, children: [], undo_parents: [], redo_parents: []})

          # bid [root]
          expect(node_props(tree[3])).to eq({parent: nil, child: 4, children: [4, 5], undo_parents: [], redo_parents: []})

          # chat [head]
          expect(node_props(tree[4])).to eq({parent: 3, child: nil, children: [], undo_parents: [], redo_parents: []})

          # end_game [head]
          expect(node_props(tree[5])).to eq({parent: 3, child: nil, children: [], undo_parents: [], redo_parents: []})
        end

        it 'throws an error if duplicate action IDs are found' do
          expect { get_action_tree('1889/ActionTree_duplicate_ids') }.to raise_error(Engine::ActionTreeError)
        end

        it 'sets parents, children, and child with undo and redo actions present' do
          tree = get_action_tree('1889/ActionTree2')

          # message
          expect(node_props(tree[1])).to eq({parent: nil, child: nil, children: [], undo_parents: [], redo_parents: []})

          # bid [root]
          expect(node_props(tree[2])).to eq({parent: nil, child: 3, children: [3], undo_parents: [9], redo_parents: []})

          # bid
          expect(node_props(tree[3])).to eq({parent: 2, child: 8, children: [4, 8], undo_parents: [7], redo_parents: []})

          # bid (undone by action 7)
          expect(node_props(tree[4])).to eq({parent: 3, child: 7, children: [5, 7], undo_parents: [6], redo_parents: []})

          # bid (undone by action 6)
          expect(node_props(tree[5])).to eq({parent: 4, child: 6, children: [6], undo_parents: [], redo_parents: []})

          # undo
          expect(node_props(tree[6])).to eq({parent: 5, child: 4, children: [4], undo_parents: [], redo_parents: []})

          # undo
          expect(node_props(tree[7])).to eq({parent: 4, child: 3, children: [3], undo_parents: [], redo_parents: []})

          # bid (undone by 9, redone by 10)
          expect(node_props(tree[8])).to eq({parent: 3, child: 11, children: [9, 11], undo_parents: [], redo_parents: [10]})

          # undo (action_id: 2, undone by 10)
          expect(node_props(tree[9])).to eq({parent: 8, child: 10, children: [2, 10], undo_parents: [], redo_parents: []})

          # redo (undo 9, set head to 8)
          expect(node_props(tree[10])).to eq({parent: 9, child: 8, children: [8], undo_parents: [], redo_parents: []})

          # bid
          expect(node_props(tree[11])).to eq({parent: 8, child: 12, children: [12], undo_parents: [], redo_parents: []})

          # bid
          expect(node_props(tree[12])).to eq({parent: 11, child: 13, children: [13], undo_parents: [], redo_parents: []})

          # bid
          expect(node_props(tree[13])).to eq({parent: 12, child: 14, children: [14], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[14])).to eq({parent: 13, child: 15, children: [15], undo_parents: [], redo_parents: []})

          # par
          expect(node_props(tree[15])).to eq({parent: 14, child: 16, children: [16], undo_parents: [], redo_parents: []})

          # program_buy_shares
          expect(node_props(tree[16])).to eq({parent: 15, child: 17, children: [17], undo_parents: [], redo_parents: []})

          # par
          expect(node_props(tree[17])).to eq({parent: 16, child: 18, children: [18], undo_parents: [27], redo_parents: []})

          # pass (undone by 27, redone by 28)
          expect(node_props(tree[18])).to eq({parent: 17, child: 32, children: [19, 27, 32], undo_parents: [26, 31], redo_parents: [28]})

          # buy_shares (undone by 26, redone by 29)
          expect(node_props(tree[19])).to eq({parent: 18, child: 26, children: [20, 23, 26], undo_parents: [25], redo_parents: [29]})

          # message
          expect(node_props(tree[20])).to eq({parent: 19, child: 21, children: [21], undo_parents: [], redo_parents: []})

          # message
          expect(node_props(tree[21])).to eq({parent: 20, child: 22, children: [22], undo_parents: [], redo_parents: []})

          # message
          expect(node_props(tree[22])).to eq({parent: 21, child: nil, children: [], undo_parents: [], redo_parents: []})

          # sell_shares (undone by 25)
          expect(node_props(tree[23])).to eq({parent: 19, child: 31, children: [24, 25, 31], undo_parents: [], redo_parents: [30]})

          # message
          expect(node_props(tree[24])).to eq({parent: 23, child: nil, children: [], undo_parents: [], redo_parents: []})

          # undo (undone by 30)
          expect(node_props(tree[25])).to eq({parent: 23, child: 30, children: [19, 30], undo_parents: [], redo_parents: []})

          # undo (undone by 29)
          expect(node_props(tree[26])).to eq({parent: 19, child: 29, children: [18, 29], undo_parents: [], redo_parents: []})

          # undo (undone by 28)
          expect(node_props(tree[27])).to eq({parent: 18, child: 28, children: [17, 28], undo_parents: [], redo_parents: []})

          # redo (undo 27, set head to 18)
          expect(node_props(tree[28])).to eq({parent: 27, child: 18, children: [18], undo_parents: [], redo_parents: []})

          # redo (undo 26, set head to 19)
          expect(node_props(tree[29])).to eq({parent: 26, child: 19, children: [19], undo_parents: [], redo_parents: []})

          # redo (undo 25, set head to 23)
          expect(node_props(tree[30])).to eq({parent: 25, child: 23, children: [23], undo_parents: [], redo_parents: []})

          # undo (action_id: 18)
          expect(node_props(tree[31])).to eq({parent: 23, child: 18, children: [18], undo_parents: [], redo_parents: []})

          # buy_shares
          expect(node_props(tree[32])).to eq({parent: 18, child: 33, children: [33], undo_parents: [], redo_parents: []})

          # program_buy_shares
          expect(node_props(tree[33])).to eq({parent: 32, child: 34, children: [34], undo_parents: [], redo_parents: []})

          # program_buy_shares
          expect(node_props(tree[34])).to eq({parent: 33, child: 35, children: [35], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[35])).to eq({parent: 34, child: 36, children: [36], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[36])).to eq({parent: 35, child: 37, children: [37], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[37])).to eq({parent: 36, child: 38, children: [38], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[38])).to eq({parent: 37, child: 41, children: [39, 41], undo_parents: [40], redo_parents: []})

          # lay_tile (undone by 40)
          expect(node_props(tree[39])).to eq({parent: 38, child: 40, children: [40], undo_parents: [], redo_parents: []})

          # undo
          expect(node_props(tree[40])).to eq({parent: 39, child: 38, children: [38], undo_parents: [], redo_parents: []})

          # lay_tile
          expect(node_props(tree[41])).to eq({parent: 38, child: 42, children: [42], undo_parents: [], redo_parents: []})

          # lay_tile
          expect(node_props(tree[42])).to eq({parent: 41, child: 43, children: [43], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[43])).to eq({parent: 42, child: 44, children: [44], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[44])).to eq({parent: 43, child: 45, children: [45], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[45])).to eq({parent: 44, child: 46, children: [46], undo_parents: [], redo_parents: []})

          # buy_shares
          expect(node_props(tree[46])).to eq({parent: 45, child: 47, children: [47], undo_parents: [], redo_parents: []})

          # buy_shares
          expect(node_props(tree[47])).to eq({parent: 46, child: 48, children: [48], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[48])).to eq({parent: 47, child: 49, children: [49], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[49])).to eq({parent: 48, child: 50, children: [50], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[50])).to eq({parent: 49, child: 51, children: [51], undo_parents: [], redo_parents: []})

          # lay_tile
          expect(node_props(tree[51])).to eq({parent: 50, child: 52, children: [52], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[52])).to eq({parent: 51, child: 53, children: [53], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[53])).to eq({parent: 52, child: 54, children: [54], undo_parents: [], redo_parents: []})

          # pass
          expect(node_props(tree[54])).to eq({parent: 53, child: 55, children: [55], undo_parents: [], redo_parents: []})

          # lay_tile
          expect(node_props(tree[55])).to eq({parent: 54, child: 56, children: [56], undo_parents: [], redo_parents: []})

          # run_routes
          expect(node_props(tree[56])).to eq({parent: 55, child: 57, children: [57], undo_parents: [], redo_parents: []})

          # dividend
          expect(node_props(tree[57])).to eq({parent: 56, child: 58, children: [58], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[58])).to eq({parent: 57, child: 59, children: [59], undo_parents: [], redo_parents: []})

          # buy_train
          expect(node_props(tree[59])).to eq({parent: 58, child: 60, children: [60], undo_parents: [], redo_parents: []})

          # end_game [head]
          expect(node_props(tree[60])).to eq({parent: 59, child: nil, children: [], undo_parents: [], redo_parents: []})
        end
      end

      describe '#filtered_actions' do
        describe 'with include_chat: false' do
          it 'excludes chats' do
            tree = get_action_tree('1889/ActionTree1')

            head = 4
            actions = tree.filtered_actions(head, include_chat: false)
            action_ids = actions.map { |a| a['id'] }

            expect(action_ids).to eq([3, 4])
          end

          # rubocop:disable Layout/LineLength
          {
            1 => [],
            2 => [2],
            3 => [2, 3],
            4 => [2, 3, 4],
            5 => [2, 3, 4, 5],
            6 => [2, 3, 4],
            7 => [2, 3],
            8 => [2, 3, 8],
            9 => [2],
            10 => [2, 3, 8],
            11 => [2, 3, 8, 11],
            12 => [2, 3, 8, 11, 12],
            13 => [2, 3, 8, 11, 12, 13],
            14 => [2, 3, 8, 11, 12, 13, 14],
            15 => [2, 3, 8, 11, 12, 13, 14, 15],
            16 => [2, 3, 8, 11, 12, 13, 14, 15, 16],
            17 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17],
            18 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            19 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            20 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            21 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            22 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            23 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 23],
            24 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 23],
            25 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            26 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            27 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17],
            28 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            29 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            30 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 23],
            31 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            32 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32],
            33 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33],
            34 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34],
            35 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35],
            36 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36],
            37 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37],
            38 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38],
            39 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 39],
            40 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38],
            41 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41],
            42 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42],
            43 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43],
            44 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44],
            45 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45],
            46 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46],
            47 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47],
            48 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48],
            49 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49],
            50 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50],
            51 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51],
            52 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52],
            53 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53],
            54 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54],
            55 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55],
            56 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56],
            57 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
            58 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58],
            59 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59],
            60 => [2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60],
          }.each do |head, expected|
            # rubocop:enable Layout/LineLength
            it "filters actions correctly for ActionTree2 at head: #{head}" do
              tree = get_action_tree('1889/ActionTree2')
              actual = tree.filtered_actions(head, include_chat: false).map { |a| a['id'] }
              expect(actual).to eq(expected)
            end
          end

          # rubocop:disable Layout/LineLength
          {
            1 => [], # chat
            2 => [], # chat
            3 => [], # chat
            4 => [], # chat
            5 => [5],
            6 => [], # undo
            7 => [7],
            8 => [7], # chat
            9 => [7], # chat
            10 => [7], # chat
            11 => [7], # chat
            12 => [], # undo
            13 => [13],
            14 => [13, 14],
            15 => [13], # undo
            16 => [13], # chat
            17 => [13, 17],
            18 => [13], # undo
            19 => [13], # chat
            20 => [13, 20],
            21 => [13, 20, 21],
          }.each do |head, expected|
            # rubocop:enable Layout/LineLength
            it "filters actions correctly for ActionTree3 at head: #{head}" do
              tree = get_action_tree('1889/ActionTree3')
              actual = tree.filtered_actions(head, include_chat: false).map { |a| a['id'] }
              expect(actual).to eq(expected)
            end
          end
        end

        describe 'with include_chat: true' do
          xit 'includes chats at root' do
            tree = get_action_tree('1889/ActionTree1')

            head = 4
            actions = tree.filtered_actions(head, include_chat: true)
            action_ids = actions.map { |a| a['id'] }

            expect(action_ids).to eq([1, 2, 3, 5, 4])
          end

          {
            1 => [1],
            # 2 => [1, 2],
            # 3 => [1, 2, 3],
            # 4 => [1, 2, 3, 4],
            # 5 => [1, 2, 3, 4, 5],
            # 6 => [1, 2, 3, 4],
            # 7 => [1, 2, 3],
            # 8 => [1, 2, 3, 8],
            # 9 => [1, 2],
            # 10 => [1, 2, 3, 8],
            # 11 => [1, 2, 3, 8, 11],
            # 12 => [1, 2, 3, 8, 11, 12],
            # 13 => [1, 2, 3, 8, 11, 12, 13],
            # 14 => [1, 2, 3, 8, 11, 12, 13, 14],
            # 15 => [1, 2, 3, 8, 11, 12, 13, 14, 15],
            # 16 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16],
            # 17 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17],
            # 18 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            # 19 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            # 20 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
            # 21 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
            # 22 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
            # 23 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23],
            # 24 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
            # 25 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            # 26 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            # 27 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17],
            # 28 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            # 29 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19],
            # 30 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 23],
            # 31 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18],
            # 32 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32],
            # 33 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33],
            # 34 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34],
            # 35 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35],
            # 36 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36],
            # 37 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37],
            # 38 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38],
            # 39 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 39],
            # 40 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38],
            # 41 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41],
            # 42 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42],
            # 43 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43],
            # 44 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44],
            # 45 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45],
            # 46 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46],
            # 47 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47],
            # 48 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48],
            # 49 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49],
            # 50 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50],
            # 51 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51],
            # 52 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52],
            # 53 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53],
            # 54 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54],
            # 55 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55],
            # 56 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56],
            # 57 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57],
            # 58 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58],
            # 59 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59],
            # 60 => [1, 2, 3, 8, 11, 12, 13, 14, 15, 16, 17, 18, 32, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60],
          }.each do |head, expected|
            it "filters actions correctly for ActionTree2 at head: #{head}" do
              tree = get_action_tree('1889/ActionTree2')
              actual = tree.filtered_actions(head, include_chat: true).map { |a| a['id'] }
              expect(actual).to eq(expected)
            end
          end

          # rubocop:disable Layout/LineLength
          {
            1 => [1], # chat
            2 => [1, 2], # chat
            3 => [1, 2, 3], # chat
            4 => [1, 2, 3, 4], # chat
            5 => [1, 2, 3, 4, 5],
            6 => [1, 2, 3, 4], # undo
            7 => [1, 2, 3, 4, 7],
            8 => [1, 2, 3, 4, 7, 8], # chat
            9 => [1, 2, 3, 4, 7, 8, 9],
            10 => [1, 2, 3, 4, 7, 8, 9, 10],
            11 => [1, 2, 3, 4, 7, 8, 9, 10, 11],
            12 => [1, 2, 3, 4, 8, 9, 10, 11],
            13 => [1, 2, 3, 4, 8, 9, 10, 11, 13],
            14 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 14],
            15 => [1, 2, 3, 4, 8, 9, 10, 11, 13],
            16 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16], # chat
            17 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16, 17],
            18 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16], # undo
            19 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16, 19],
            20 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16, 19, 20],
            21 => [1, 2, 3, 4, 8, 9, 10, 11, 13, 16, 19, 20, 21],
          }.each do |head, expected|
            # rubocop:enable Layout/LineLength
            it "filters actions correctly for ActionTree3 at head: #{head}" do
              tree = get_action_tree('1889/ActionTree3')
              actual = tree.filtered_actions(head, include_chat: true).map { |a| a['id'] }
              expect(actual).to eq(expected)
            end
          end
        end
      end
    end
  end
end
