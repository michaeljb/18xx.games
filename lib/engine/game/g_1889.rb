require_relative 'meta'

module Engine
  module Game
    module G1889
      module Meta
        include Game::Meta

        DEV_STAGE = :production

        GAME_LOCATION = 'Shikoku, Japan'
        GAME_PUBLISHER = :grand_trunk_games

        PLAYER_RANGE = [2, 6]
      end
    end
  end
end
