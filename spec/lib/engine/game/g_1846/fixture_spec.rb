# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1846 do
      describe 10_264 do
        it 'does not block the track and token step for an unused company tile-lay ability' do
          game = fixture_at_action(260)

          expect(game.current_entity).to eq(game.illinois_central)
          expect(game.michigan_central.owner).to eq(game.illinois_central)
          expect(game.abilities(game.michigan_central, :tile_lay).count).to eq(2)
          expect(game.active_step).to be_a(Step::Dividend)
        end
      end

      describe 19_962 do
        it 'removes the reservation when a token is placed' do
          game = fixture_at_action(114)
          city = game.hex_by_id('D20').tile.cities.first
          corp = game.corporation_by_id('ERIE')
          expect(city.reserved_by?(corp)).to be(false)
        end

        it 'has correct reservations and tokens after NYC closes' do
          game = fixture_at_action(162)
          city = game.hex_by_id('D20').tile.cities.first
          erie = game.corporation_by_id('ERIE')

          expect(city.reservations).to eq([nil, nil])
          expect(city.tokens.map { |t| t&.corporation }).to eq([nil, erie])
        end

        it 'has a cert limit of 12 at the start of a 4p game' do
          game = fixture_at_action(0)
          expect(game.cert_limit).to be(12)
        end

        it 'has a cert limit of 10 after a corporation closes' do
          game = fixture_at_action(122)
          expect(game.cert_limit).to be(10)
        end

        it 'has a cert limit of 10 after a corporation closes and then a player is bankrupt' do
          game = fixture_at_action(300)
          expect(game.cert_limit).to be(10)
        end

        it 'has a cert limit of 8 after a corporation closes, then a player is '\
           'bankrupt, and then another corporation closes' do
          game = fixture_at_action(328)
          expect(game.cert_limit).to be(8)
        end

        it 'IC to lay a tile on J4 for free' do
          game = fixture_at_action(64)
          expect(game.illinois_central.cash).to be(280)

          game = fixture_at_action(65)
          expect(game.illinois_central.cash).to be(280)
        end
      end

      describe 20_381 do
        it 'cannot go bankrupt when shares can be emergency issued' do
          game = fixture_at_action(308)
          prr = game.corporation_by_id('PRR')
          expect(game.can_go_bankrupt?(prr.player, prr)).to be(false)
          expect(game.emergency_issuable_cash(prr)).to eq(10)
        end
      end
    end
  end
end
