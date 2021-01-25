require_relative 'game/title'

module Engine
  module G1889
    module Meta
      include Engine::Game::Title

      DEV_STAGE = :production

      GAME_LOCATION = 'Shikoku, Japan'
      GAME_PUBLISHER = :grand_trunk_games
    end
  end
end
