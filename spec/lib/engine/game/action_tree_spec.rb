# frozen_string_literal: true

require './spec/spec_helper'

# @param fixture [String] "<title>/<id>" for a JSON file in fixtures/
# @param kwargs [Hash] forwarded to Engine::Game#load
# @returns [ActionTree] the tree to inspect for testing
def get_action_tree(fixture, **_kwargs)
  filename = File.join('public', 'fixtures', "#{fixture}.json")
  raise "#{filename} does not exist" unless File.exist?(filename)

  game = Engine::Game.load(filename).maybe_raise!
  game.action_tree
end

module Engine
  module Game
    describe ActionTree do
      describe '1889/tree1' do
        let(:tree) do
          get_action_tree('1889/tree1')
        end

        describe '#new' do
          it 'sets parents, children, and child' do
            expect(tree[1].parent).to be_nil
            expect(tree[1].child.id).to eq(2)
            expect(tree[1].children.map(&:id)).to eq([2])

            expect(tree[2].parent.id).to eq(1)
            expect(tree[2].child).to be_nil
            expect(tree[2].children).to eq(Set.new)

            # chat 5 is not the main child, but branched
            expect(tree[3].parent).to be_nil
            expect(tree[3].child.id).to eq(4)
            expect(tree[3].children.map(&:id)).to eq([5, 4])

            expect(tree[5].parent.id).to eq(3)
            expect(tree[5].child).to be_nil
            expect(tree[5].children).to eq(Set.new)

            expect(tree[4].parent.id).to eq(3)
            expect(tree[4].child).to be_nil
            expect(tree[4].children).to eq(Set.new)
          end
        end

        describe '#filtered_actions' do
          it 'excludes chats' do
            head = 4
            actions = tree.filtered_actions(head, include_chat: false)
            action_ids = actions.map { |a| a['id'] }

            expect(action_ids).to eq([3, 4])
          end

          it 'includes chats at root' do
            head = 4
            actions = tree.filtered_actions(head, include_chat: true)
            action_ids = actions.map { |a| a['id'] }

            expect(action_ids).to eq([1, 2, 3, 5, 4])
          end
        end
      end
    end
  end
end
