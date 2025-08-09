# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1861 do
      describe 167_259 do
        it 'minors are nationalised in operating order' do
          # Checking RSR token locations and order tells us if the minors
          # have been nationalised in the correct order.
          game = fixture_at_action(673)
          hexes = game.corporation_by_id('RSR').placed_tokens.map(&:hex).map(&:coordinates)
          expect(hexes).to eq(%w[E1 D14 D20 K17 I19 H8 B4 E9])
        end

        it 'majors are nationalised in operating order' do
          # MKN should be the first to be potentially nationalised.
          game = fixture_at_action(582)
          corporation = game.corporation_by_id('MKN')
          expect(game.current_entity).to eq(corporation)
        end
      end
    end
  end
end
