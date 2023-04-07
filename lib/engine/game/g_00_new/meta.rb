# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G00New
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha

        GAME_TITLE = '00New'

        GAME_DESIGNER = ''
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18New'
        GAME_LOCATION = ''
        GAME_PUBLISHER = nil
        GAME_RULES_URL = ''

        PLAYER_RANGE = [2, 6].freeze
        OPTIONAL_RULES = [].freeze
      end
    end
  end
end
