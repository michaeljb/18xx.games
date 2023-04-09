# frozen_string_literal: true

require_relative '../g_1830/entities'

module Engine
  module Game
    module GHiawathas
      module Entities
        HOME_COORDINATES = {
          'B&O' => 'H9',
          'C&O' => 'F9',
          'CPR' => 'F1',
          'ERIE' => 'C8',
          'NYC' => 'H9',
          'PRR' => 'D9',
        }.freeze

        # use all the 1830 corporations except B&M and NYNH, give them homes for
        # the new map
        CORPORATIONS = G1830::Entities::CORPORATIONS.dup[0..5].map do |corp|
          corp[:coordinates] = HOME_COORDINATES[corp[:sym]]
          corp
        end

        COMPANIES = [
          {
            name: 'Schuylkill Valley',
            sym: 'SV',
            value: 20,
            revenue: 5,
            desc: 'No special abilities.',
            abilities: [],
            color: nil,
          },
          {
            name: 'Champlain & St.Lawrence',
            sym: 'CS',
            value: 40,
            revenue: 10,
            desc: "A corporation owning the CS may lay a tile on the CS's hex even if this hex is not connected"\
                  " to the corporation's track. This free tile placement is in addition to the corporation's normal tile"\
                  ' placement. Blocks H5 while owned by a player.',
            abilities: [{ type: 'blocks_hexes', owner_type: 'player', hexes: ['H5'] },
                        {
                          type: 'tile_lay',
                          owner_type: 'corporation',
                          hexes: ['H5'],
                          tiles: [],
                          when: 'owning_corp_or_turn',
                          count: 1,
                        }],
            color: nil,
          },
          {
            name: 'Delaware & Hudson',
            sym: 'DH',
            value: 70,
            revenue: 15,
            desc: 'A corporation owning the DH may place a tile and station token in the DH hex E4 for free.'\
                  " The station does not have to be connected to the remainder of the corporation's"\
                  " route. The tile laid is the owning corporation's"\
                  ' one tile placement for the turn. Blocks E4 while owned by a player.',
            abilities: [{ type: 'blocks_hexes', owner_type: 'player', hexes: ['E4'] },
                        {
                          type: 'teleport',
                          owner_type: 'corporation',
                          tiles: ['57'],
                          hexes: ['E4'],
                        }],
            color: nil,
          },
          {
            name: 'Mohawk & Hudson',
            sym: 'MH',
            value: 110,
            revenue: 20,
            desc: 'A player owning the MH may exchange it for a 10% share of the NYC if they do not already hold 60%'\
                  ' of the NYC and there is NYC stock available in the Bank or the Pool. The exchange may be made during'\
                  " the player's turn of a stock round or between the turns of other players or corporations in either "\
                  'stock or operating rounds. This action closes the MH.',
            abilities: [{
                          type: 'exchange',
                          corporations: ['NYC'],
                          owner_type: 'player',
                          when: 'any',
                          from: %w[ipo market],
                        }],
            color: nil,
          },
          {
            name: 'Camden & Amboy',
            sym: 'CA',
            value: 160,
            revenue: 25,
            desc: 'The initial purchaser of the CA immediately receives a 10% share of PRR stock without further'\
                  ' payment. This action does not close the CA. The PRR corporation will not be running at this point,'\
                  ' but the stock may be retained or sold subject to the ordinary rules of the game.',
            abilities: [{ type: 'shares', shares: 'PRR_1' }],
            color: nil,
          },
          {
            name: 'Baltimore & Ohio',
            sym: 'BO',
            value: 220,
            revenue: 30,
            desc: "The owner of the BO private company immediately receives the President's certificate of the"\
                  ' B&O without further payment. The BO private company may not be sold to any corporation, and does'\
                  ' not exchange hands if the owning player loses the Presidency of the B&O.'\
                  ' When the B&O purchases its first train the private company is closed.',
            abilities: [{ type: 'close', when: 'bought_train', corporation: 'B&O' },
                        { type: 'no_buy' },
                        { type: 'shares', shares: 'B&O_0' }],
            color: nil,
          },
        ].freeze
      end
    end
  end
end
