# frozen_string_literal: true

require_relative '../../../round/stock'

module Engine
  module Game
    module GSystem18
      module Round
        class Stock < Engine::Round::Stock
          def finish_round
            super
            return unless @game.corporations.none?(&:floated)

            @log << '-- Round ended with no floated corporations. Ending game. --'
            @game.end_game!(:didnt_really_want_to_play)
          end
        end
      end
    end
  end
end
