# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G18Norway do
      describe '18_norway_buy_ship' do
        context 'share selling' do
          let(:first_action_type) { 'sell_shares' }

          it 'Should not allow selling president\'s share if NSB would become president' do
            game = fixture_at_action(first_action_of_type: first_action_type)
            corporation = game.corporations.find { |c| c != game.nsb }

            # Ensure corporation has a share price
            share_price = game.stock_market.par_prices.first
            game.stock_market.set_par(corporation, share_price)

            # Give NSB enough shares to become president if current president sells
            shares = game.shares.select { |s| s.corporation == corporation }.take(2)
            game.share_pool.transfer_shares(
              Engine::ShareBundle.new(shares),
              game.nsb
            )

            # Try to sell president's share
            bundle = Engine::ShareBundle.new(game.shares.select { |s| s.corporation == corporation && s.president })
            expect do
              game.sell_shares_and_change_price(bundle)
            end.to raise_error(GameError, 'Cannot sell shares as NSB would become president')
          end

          it 'Should allow selling president\'s share if another player has 20%' do
            game = fixture_at_action(first_action_of_type: first_action_type)
            corporation = game.corporations.find { |c| c != game.nsb }
            other_player = game.players[1]

            # Ensure corporation has a share price
            share_price = game.stock_market.par_prices.first
            game.stock_market.set_par(corporation, share_price)

            # Give NSB enough shares to become president if current president sells
            shares = game.shares.select { |s| s.corporation == corporation }.take(2)
            game.share_pool.transfer_shares(
              Engine::ShareBundle.new(shares),
              game.nsb
            )

            # Give other player 20% shares
            shares = game.shares.select { |s| s.corporation == corporation }.take(2)
            game.share_pool.transfer_shares(
              Engine::ShareBundle.new(shares),
              other_player
            )

            # Try to sell president's share
            bundle = Engine::ShareBundle.new(game.shares.select { |s| s.corporation == corporation && s.president })
            expect { game.sell_shares_and_change_price(bundle) }.not_to raise_error
          end

          it 'Should not allow selling president\'s share if no other player has 20%' do
            game = fixture_at_action(first_action_of_type: first_action_type)
            corporation = game.corporations.find { |c| c != game.nsb }
            other_player = game.players[1]

            # Ensure corporation has a share price
            share_price = game.stock_market.par_prices.first
            game.stock_market.set_par(corporation, share_price)

            # Give NSB enough shares to become president if current president sells
            shares = game.shares.select { |s| s.corporation == corporation }.take(2)
            game.share_pool.transfer_shares(
              Engine::ShareBundle.new(shares),
              game.nsb
            )

            # Give other player only 10% shares
            shares = game.shares.select { |s| s.corporation == corporation }.take(1)
            game.share_pool.transfer_shares(
              Engine::ShareBundle.new(shares),
              other_player
            )

            # Try to sell president's share
            bundle = Engine::ShareBundle.new(game.shares.select { |s| s.corporation == corporation && s.president })
            expect { game.sell_shares_and_change_price(bundle) }.to raise_error(GameError)
          end

          it 'Should allow selling non-president shares' do
            game = fixture_at_action(first_action_of_type: first_action_type)
            corporation = game.corporations.find { |c| c != game.nsb }

            # Ensure corporation has a share price
            share_price = game.stock_market.par_prices.first
            game.stock_market.set_par(corporation, share_price)

            # Try to sell non-president share
            bundle = Engine::ShareBundle.new(game.shares.select { |s| s.corporation == corporation && !s.president })
            expect { game.sell_shares_and_change_price(bundle) }.not_to raise_error
          end
        end
      end
    end
  end
end
