# frozen_string_literal: true

module Engine
  module Game
    module G18Neb
      module Entities
        COMPANIES = [
          {
            name: 'P1 - Denver Pacific Railroad',
            value: 20,
            revenue: 5,
            desc: 'Once per game, allows Corporation to lay or upgrade a tile in B8, '\
                  'in addition to and either before or after its normal tile lay(s).',
            sym: 'DPR',
            abilities: [
              {
                type: 'blocks_hexes',
                remove: '3',
                hexes: %w[B8],
              },
              {
                type: 'tile_lay',
                owner_type: 'corporation',
                hexes: %w[B8],
                tiles: %w[7 8 9 80 81 82 83],
                count: 1,
              },
            ],
          },
          {
            name: 'P2 - Morison Bridging Company',
            value: 40,
            revenue: 10,
            desc: 'Corporation gets two bridge discount tokens, each of which will offset up to $60 '\
                  'off bridge building in a single OR. Company closes if both tokens are used. Tokens '\
                  'are available until phase 6.',
            sym: 'P2',
            abilities: [
              {
                type: 'tile_discount',
                description: 'Bridge discount tokens',
                discount: 60,
                terrain: 'water',
                owner_type: 'corporation',
                hexes: %w[K3 K5 K7 J8 L8 L10],
                count_per_or: 1,
                count: 2,
                closed_when_used_up: true,
                remove: '6',
              },
              # TODO: keep tokens on close
            ],
          },
          {
            name: 'P3 - Armour and Company',
            value: 70,
            revenue: 15,
            desc: 'Corporation may place a cattle token in any Town or City (not offboard) during '\
                  'its token placement step. Once placed, the corporation gets a $20 bonus for the selected '\
                  'Town or City. The token starts as an Open token, which allows other corporations to get '\
                  'a $10 bonus for the selected Town or City. The token may be converted to a closed token, '\
                  'which removes the $10 bonus for other corporations, but closes the private.',
            sym: 'P3',
            abilities: [
              {
                type: 'assign_hexes',
                hexes: %w[B6 C3 C7 C9 E7 F6 G7 G11 H8 H10 I3 I5 J8 J12 K3 K7 L10],
                count: 1,
                when: 'token',
                owner_type: 'corporation',
              },
              # TODO: convert to closed token
              # TODO add in route revenue
              # TODO cattle token
              # Remove token on phase 6
            ],
          },
          {
            name: 'P4 - Central Pacific Railroad',
            value: 100,
            revenue: 15,
            desc: 'In lieu of a stock purchase during a Stock Round, the owning player may exchange '\
                  'this company, which closes it, for a share of the Colorado and Southern Railway, '\
                  'if available. The C&S receives its current Stock Price from the Bank if the share '\
                  'was taken from its Treasury.',
            sym: 'P4',
            abilities: [
                {
                  type: 'exchange',
                  corporations: %w[C&S],
                  owner_type: 'player',
                  when: 'owning_player_sr_turn',
                  from: %w[ipo market],
                },
                {
                  type: 'blocks_hexes',
                  owner_type: 'player',
                  hexes: ['C7'],
                  remove: '3',
                },
              ],
          },
          {
            name: 'P5 - Crédit Mobilier',
            value: 130,
            revenue: 5,
            desc: 'The owner receives $5 each time ANY tile is placed or upgraded, regardless of which Corporation '\
                  'laid it. In lieu of a stock purchase during a Stock Round, the owning player may exchange this '\
                  'company, which closes it, for a share of the Union Pacific Railroad, if available. The UP '\
                  'receives its current Stock Price from the Bank if the share was taken from its Treasury. '\
                  'May not be sold to a corporation for more than face value.',
            sym: 'P5',
            abilities: [
              {
                type: 'tile_income',
                income: 5,
              },
              {
                type: 'exchange',
                corporations: %w[UP],
                owner_type: 'player',
                when: 'owning_player_sr_turn',
                from: %w[ipo market],
              },
              # TODO: exchange pay the corporation if incremental
            ],
          },
          {
            name: 'P6 - Union Pacific Railroad',
            value: 175,
            revenue: 25,
            desc: "Comes with President's Certificate of the Union Pacific Railroad. This company cannot be sold "\
                  'to a corporation. The company closes when the Union Pacific Railroad buys its first train.',
            sym: 'P6',
            abilities: [
              { type: 'shares', shares: 'UP_0' },
              { type: 'close', when: 'bought_train', corporation: 'UP' },
              { type: 'no_buy' },
            ],
          },
        ].freeze

        def corporation_opts
          { always_market_price: true }
        end

        CORPORATIONS = [
          {
            float_percent: 20,
            sym: 'CBQ',
            name: 'Chicago Burlington & Quincy',
            logo: '18_neb/CBQ',
            tokens: [0, 40, 100, 100],
            coordinates: 'L6',
            color: '#666666',
          },
          {
            float_percent: 20,
            sym: 'CNW',
            name: 'Chicago & Northwestern',
            logo: '18_neb/CNW',
            tokens: [0, 40, 100],
            coordinates: 'L4',
            color: '#2C9846',
          },
          {
            float_percent: 20,
            sym: 'C&S',
            name: 'Colorado & Southern',
            logo: '18_neb/CS',
            tokens: [0, 40, 100, 100],
            coordinates: 'A7',
            color: '#AE4A84',
          },
          {
            float_percent: 20,
            sym: 'DRG',
            name: 'Denver & Rio Grande',
            logo: '18_neb/DRG',
            tokens: [0, 40],
            coordinates: 'C9',
            color: '#D4AF37',
            text_color: 'black',
          },
          {
            float_percent: 20,
            sym: 'MP',
            name: 'Missouri Pacific',
            logo: '18_neb/MP',
            tokens: [0, 40, 100],
            coordinates: 'L12',
            color: '#874301',
          },
          {
            float_percent: 20,
            sym: 'UP',
            name: 'Union Pacific',
            logo: '18_neb/UP',
            tokens: [0, 40, 100],
            coordinates: 'K7',
            color: '#376FFF',
          },
          {
            float_percent: 40,
            sym: 'NR',
            name: 'NebKota',
            logo: '18_neb/NR',
            shares: [40, 20, 20, 20],
            tokens: [0, 40],
            coordinates: 'C3',
            max_ownership_percent: 100,
            color: '#000000',
            type: 'local',
          },
          {
            float_percent: 40,
            sym: 'OLB',
            name: 'Omaha, Lincoln & Beatrice',
            logo: '18_neb/OLB',
            shares: [40, 20, 20, 20],
            tokens: [0, 40],
            coordinates: 'K7',
            max_ownership_percent: 100,
            color: '#F40003',
            type: 'local',
          },
        ].freeze
      end
    end
  end
end
