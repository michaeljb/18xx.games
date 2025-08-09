# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1822PNW do
      describe 165_580 do
        it 'does not include associated minors for majors that were started '\
           'directly as valid choices for P20' do
          game = fixture_at_action(926)

          actual = game.active_step.p20_targets
          expected = [game.corporation_by_id('1')]

          expect(actual).to eq(expected)
        end
      end
    end
  end
end
