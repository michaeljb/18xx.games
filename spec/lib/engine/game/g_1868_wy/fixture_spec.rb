# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1868WY do
      describe 144_719 do
        it 'Big Boy' do
          # OR 3.1
          # RCL attaches the token to a 3+2, making a [4+3]
          game = fixture_at_action(283)
          expect(game.big_boy_train.id).to eq('3-3')
          expect(game.big_boy_train.name).to eq('[4+3]')
          expect(game.big_boy_train_original.id).to eq('3-3')
          expect(game.big_boy_train_original.name).to eq('3+2')
          expect(game.big_boy_train_dh_original).to eq(nil)

          # RCL combines the 2+2 and [4+3] to a [6+5]
          game.process_to_action(363)
          expect(game.big_boy_train.id).to eq('2-4_3-3-0')
          expect(game.big_boy_train.name).to eq('[6+5]')
          expect(game.big_boy_train_original.id).to eq('2-4_3-3-0')
          expect(game.big_boy_train_original.name).to eq('5+4')
          expect(game.big_boy_train_dh_original.id).to eq('3-3')
          expect(game.big_boy_train_dh_original.name).to eq('3+2')

          # RCL is done running the [6+5]
          game.process_to_action(365)
          expect(game.big_boy_train.id).to eq('3-3')
          expect(game.big_boy_train.name).to eq('[4+3]')
          expect(game.big_boy_train_original.id).to eq('3-3')
          expect(game.big_boy_train_original.name).to eq('3+2')
          expect(game.big_boy_train_dh_original).to eq(nil)

          # RCL bought a 4+3 and moved the token to it
          # end of RCL in OR 3.1
          game.process_to_action(367)
          expect(game.big_boy_train.id).to eq('4-0')
          expect(game.big_boy_train.name).to eq('[5+4]')
          expect(game.big_boy_train_original.id).to eq('4-0')
          expect(game.big_boy_train_original.name).to eq('4+3')
          expect(game.big_boy_train_dh_original).to eq(nil)

          # after another company finishes running double-headed trains, RCL and
          # the Big Boy should be unaffected
          game.process_to_action(385)
          expect(game.big_boy_train.id).to eq('4-0')
          expect(game.big_boy_train.name).to eq('[5+4]')
          expect(game.big_boy_train_original.id).to eq('4-0')
          expect(game.big_boy_train_original.name).to eq('4+3')
          expect(game.big_boy_train_dh_original).to eq(nil)

          # OR 3.2
          # should be the same as end of OR 3.1
          game.process_to_action(433)
          expect(game.big_boy_train.id).to eq('4-0')
          expect(game.big_boy_train.name).to eq('[5+4]')
          expect(game.big_boy_train_original.id).to eq('4-0')
          expect(game.big_boy_train_original.name).to eq('4+3')
          expect(game.big_boy_train_dh_original).to eq(nil)
        end
      end
    end

  end
end
