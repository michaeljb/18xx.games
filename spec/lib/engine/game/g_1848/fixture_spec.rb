# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1848 do
      describe 101 do
        it '2nd receivership removes the next permanent and triggers phase change' do
          game = fixture_at_action(483)

          expect(game.phase.name).to eq('5')

          expect(game.depot.upcoming.count { |train| train.name == '5' }).to eq(2)
        end
      end
    end
  end
end
