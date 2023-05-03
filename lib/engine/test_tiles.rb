# frozen_string_literal: true

module Engine
  module TestTiles
    # "interesting" tiles to display for manual visual testing
    # - game title
    #   - fixture game id
    #     - action id
    #       -  array of tile names or hex ids
    TEST_TILES = {
      nil => {
        nil => {
          nil => ['45'],
        },
      },

      '1822PNW' => {
        nil => {
          nil => %w[H11 O8 I12],
        },
      },

      '1868 Wyoming' => {
        'hs_aulsilwv_5' => {
          839 => %w[J12],
        },
      },
    }.freeze
  end
end
