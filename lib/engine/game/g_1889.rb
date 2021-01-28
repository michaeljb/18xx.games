require_relative 'title'

module Engine
  module Game
    module G1889
      module Meta
        include Title

        DEV_STAGE = :production

        GAME_LOCATION = 'Shikoku, Japan'
        GAME_PUBLISHER = :grand_trunk_games

        CERT_LIMIT = {
          2 => 25,
          3 => 19,
          4 => 14,
          5 => 12,
          6 => 11,
        }.freeze
      end
    end
  end
end
