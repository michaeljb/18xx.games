# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'market'
require_relative 'meta'
require_relative 'trains'
require_relative '../base'

module Engine
  module Game
    module G00New
      class Game < Game::Base
        include_meta(G00New::Meta)
        include Entities
        include Map
        include Market
        include Trains

        CURRENCY_FORMAT_STR = '$%s'

        BANK_CASH = 7000
        CERT_LIMIT = { 2 => 25, 3 => 19, 4 => 14, 5 => 12, 6 => 11 }.freeze
        STARTING_CASH = { 2 => 420, 3 => 420, 4 => 420, 5 => 390, 6 => 390 }.freeze

        CAPITALIZATION = :full
      end
    end
  end
end
