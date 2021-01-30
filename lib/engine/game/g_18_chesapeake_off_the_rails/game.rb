# frozen_string_literal: true

require_relative '../g_18_chesapeake/game'
require_relative 'config'
require_relative 'meta'

module Engine
  module Game
    module G18ChesapeakeOffTheRails
      class Game < G18Chesapeake::Game
        load_from_json(G18ChesapeakeOffTheRails::Config::JSON)
        load_from_meta(G18ChesapeakeOffTheRails::Meta)

        SELL_BUY_ORDER = :sell_buy_sell

        GAME_END_CHECK = { bankrupt: :immediate, stock_market: :current_round, bank: :full_or }.freeze

        def or_set_finished; end
      end
    end
  end
end
