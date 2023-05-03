# frozen_string_literal: true

module Engine
  module TestTiles
    # "interesting" tiles to display for manual visual testing
    # - tile / hex id
    # - game title (optional)
    # - fixture (optional, requires game title)
    # - action id (optional, requires fixture)
    # -  array of tile names or hex ids
    TEST_TILES_HUMAN_READABLE = [
      ['45'],

      %w[H11 1822PNW],
      %w[O8 1822PNW],
      %w[I12 1822PNW],

      ['L0', '1868 Wyoming'],
      ['L0', '1868 Wyoming', 'hs_aulsilwv_5', 835],
      ['J12', '1868 Wyoming', 'hs_aulsilwv_5', 835],
      ['J12', '1868 Wyoming', 'hs_aulsilwv_5'],
    ].freeze

    # rearrange the above to a structure that can be more efficiently iterated
    # over--each fixture only needs to be fetched once, and only needs to be
    # processed to each unique action once, etc
    #
    # defining with this structure directly is confusing to read; for generic
    # tiles, all of the keys in the nested Hash are `nil`
    TEST_TILES =
      TEST_TILES_HUMAN_READABLE.each_with_object({}) do |(hex_or_tile, title, fixture, action), test_tiles|
        test_tiles[title] ||= {}
        test_tiles[title][fixture] ||= {}
        test_tiles[title][fixture][action] ||= []

        test_tiles[title][fixture][action] << hex_or_tile
      end.freeze
  end
end
