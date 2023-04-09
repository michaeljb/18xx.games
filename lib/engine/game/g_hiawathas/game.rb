# frozen_string_literal: true

require_relative 'entities'
require_relative 'map'
require_relative 'market'
require_relative 'meta'
require_relative 'trains'
require_relative '../base'
require_relative '../g_1830/game'

module Engine
  module Game
    module GHiawathas
      class Game < G1830::Game
        include_meta(GHiawathas::Meta)
        include Entities
        include Map
        include Market
        include Trains

        BANK_CASH = 6500
        CERT_LIMIT = { 2 => 19, 3 => 15, 4 => 12 }.freeze
        STARTING_CASH = { 2 => 1000, 3 => 700, 4 => 550 }.freeze

        TILE_LAYS = [{ lay: true, upgrade: true }, { lay: true, upgrade: true }].freeze

        def upgrades_to?(from, to, special = false, selected_company: nil)
          to.paths.size == from.paths.size + 1 && super
        end

        def upgrades_to_correct_color?(from, to, selected_company: nil)
          from.color == to.color
        end

        def upgrades_to_correct_city_town?(from, to)
          from.cities.first&.slots == to.cities.first&.slots && super
        end

        def legal_tile_rotation?(_entity, hex, tile)
          hex.tile.color == :yellow ? tile.rotation == 0 : true
        end
      end
    end
  end
end
