# frozen_string_literal: true

module Engine
  module TestTiles
    # "interesting" tiles to display for manual visual testing; each entry is an
    # Array containing:
    # - tile / hex id
    # - game title (optional)
    # - fixture (optional, requires game title; if not given, the starting state
    #   of the hex/tile is used)
    # - action id (optional, requires fixture; if not given, the fixture is
    #   processed to its conclusion)
    TEST_TILES_HUMAN_READABLE = [
      ['45'],

      %w[H11 1822PNW],
      %w[O8 1822PNW],
      %w[I12 1822PNW],

      ['C15', '1846'],

      ['L0', '1868 Wyoming'],
      ['WRC', '1868 Wyoming'],
      ['F12', '1868 Wyoming', 'hs_aulsilwv_5', 835],
      ['L0', '1868 Wyoming', 'hs_aulsilwv_5', 835],
      ['J12', '1868 Wyoming', 'hs_aulsilwv_5', 835],
      ['J12', '1868 Wyoming', 'hs_aulsilwv_5'],
    ].freeze

    # rearrange the above to a structure that can be more efficiently iterated
    # over--each fixture only needs to be fetched once, and only needs to be
    # processed to each unique action once
    #
    # defining with this structure directly would confusing to read; for generic
    # tiles, all of the keys in the nested Hash would end up as `nil`
    TEST_TILES =
      TEST_TILES_HUMAN_READABLE.each_with_object({}) do |(hex_or_tile, title, fixture, action), test_tiles|
        test_tiles[title] ||= {}
        test_tiles[title][fixture] ||= {}
        test_tiles[title][fixture][action] ||= []

        test_tiles[title][fixture][action] << hex_or_tile
      end.freeze
  end
end
