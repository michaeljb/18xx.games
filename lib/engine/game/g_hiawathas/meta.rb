# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module GHiawathas
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        DEPENDS_ON = '1830'

        GAME_TITLE = 'The Hiawathas'

        GAME_DESIGNER = ''
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18New'
        GAME_LOCATION = ''
        GAME_PUBLISHER = :traxx
        GAME_RULES_URL = ''

        PLAYER_RANGE = [2, 4].freeze
        OPTIONAL_RULES = [].freeze
      end
    end
  end
end
