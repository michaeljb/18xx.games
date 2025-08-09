# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G18Norway do
      describe '18_norway_buy_ship' do
        it 'Hovedbanen cash should match the auction price' do
          game = fixture_at_action(7)
          expect(game.players.map(&:cash)).to eq([300, 190, 240])
          expect(game.hovedbanen.cash).to eq(170)
          expect(game.hovedbanen.shares[0].price).to eq(80)
        end
      end
    end
  end
end
