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

module Engine
  module ActionTree
    describe Tree do
      describe '#new' do
        it 'sets parents, children, and child' do
          tree = get_action_tree('1889/ActionTree1')

          expect(tree[1].parent).to be_nil
          expect(tree[1].child.id).to eq(2)
          expect(tree[1].children.map(&:id)).to eq([2])

          expect(tree[2].parent.id).to eq(1)
          expect(tree[2].child).to be_nil
          expect(tree[2].children).to eq(Set.new)

          # chat 5 is not the main child, but branched
          expect(tree[3].parent).to be_nil
          expect(tree[3].child.id).to eq(4)
          expect(tree[3].children.map(&:id).sort).to eq([4, 5])

          expect(tree[4].parent.id).to eq(3)
          expect(tree[4].child).to be_nil
          expect(tree[4].children).to eq(Set.new)

          expect(tree[5].parent.id).to eq(3)
          expect(tree[5].child).to be_nil
          expect(tree[5].children).to eq(Set.new)
        end

        it 'throws an error if duplicate action IDs are found' do
          expect { get_action_tree('1889/ActionTree_duplicate_ids') }.to raise_error(Engine::ActionTreeError)
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
