# frozen_string_literal: true

module Engine
  module Game
    module GHiawathas
      module Map
        LAYOUT = :pointy

        BASE_TILES = {}

        def self.exits_to_paths_code(exits, lanes=[])
          exits.zip(lanes).map do |exit, lane|
            lane ? "path=a:#{exit},b:_0,lanes:#{lane}" : "path=a:#{exit},b:_0"
          end.join(';')
        end

        def self.rotations(exits)
          (0..5).map do |tick|
            rotated_exits = exits.map { |e| (e + tick) % 6 }  # .sort
          end.uniq
        end

        def self.lane_permutations(num_segments)
          [2, nil].repeated_permutation(num_segments).to_a[..-2].sort_by { |x| x.count(2) }
        end

        index = 0
        [
          [[0]],
          [[0, 1], [0, 2], [0, 3]],
          [[0, 1, 2], [0, 2, 4], [0, 1, 3], [0, 3, 5]],
          [[0, 1, 2, 3], [0, 1, 3, 4], [0, 2, 3, 4]],
          [[0, 1, 2, 3, 4]],
          [[0, 1, 2, 3, 4, 5]],
        ].each.with_index do |exitses, idx|
          num_segments = idx + 1

          permutations = lane_permutations(num_segments)

          exitses.each do |exits|
            index += 1
            BASE_TILES[index] = exits_to_paths_code(exits)

            permuted = {}
            lane_map = exits.zip

            perm_index = 0

            permutations.each.with_index do |perm|
              next if rotations(exits).any? do |rotated_exits|
                permuted.include?(rotated_exits.zip(perm).to_h)
              end
              permuted[exits.zip(perm).to_h] = 0

              code = exits_to_paths_code(exits, lanes=perm)
              perm_index += 1
              BASE_TILES["#{index}.#{perm_index}"] = code
            end
          end
        end

        TILES = {}

        def self.add_tile(id, code, color='white')
          TILES["X#{id}"] = {
            'code' => code,
            'color' => color,
            'count' => 'unlimited',
          }
        end

        BASE_TILES.each do |id, code|
          code = "junction;#{code}"
          add_tile(id, code)
        end

        puts "TILES.size = #{TILES.size}"

        BASE_TILES.each do |id, code|
          code = "junction;#{code}"
          code = "#{code};upgrade=cost:40,terrain:water"
          add_tile("#{id}B", code, 'blue')
        end

        # 1-slot cities
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_20|green_30|brown_40;#{code}"
          add_tile("#{id}C", code)
        end
        # 2-slot cities
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_20|green_30|brown_40,slots:2;#{code}"
          add_tile("#{id}CC", code)
        end

        # Chicago
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_30|green_30|brown_60,slots:4;label=Chi;#{code}"
          add_tile("#{id}Chi", code)
        end
        # Green Bay
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_20|green_40|brown_60,slots:4;label=GB;#{code}"
          add_tile("#{id}GB", code)
        end
        # Milwaukee
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_20|green_60|brown_40,slots:4;label=M;#{code}"
          add_tile("#{id}M", code)
        end
        # Twin Cities
        BASE_TILES.each do |id, code|
          code = "city=revenue:yellow_30|green_40|brown_50,slots:4;label=TC;#{code}"
          code = "#{code};upgrade=cost:40,terrain:water"
          add_tile("#{id}TC", code, color='blue')
        end

        puts "TILES.size = #{TILES.size}"

        LOCATION_NAMES = {
          'F3' => 'Saijou',
          'G4' => 'Niihama',
          '7H' => 'Ikeda',
          'A10' => 'Sukumo',
          'J11' => 'Anan',
          'G12' => 'Nahari',
          'E2' => 'Matsuyama',
          'I2' => 'Marugame',
          'K8' => 'Tokushima',
          'C10' => 'Kubokawa',
          'J5' => 'Ritsurin Kouen',
          'G10' => 'Nangoku',
          'J9' => 'Komatsujima',
          'I12' => 'Muki',
          'B11' => 'Nakamura',
          'I4' => 'Kotohira',
          'C4' => 'Ohzu',
          'K4' => 'Takamatsu',
          'B7' => 'Uwajima',
          'B3' => 'Yawatahama',
          'G14' => 'Muroto',
          'F1' => 'Imabari',
          'J1' => 'Sakaide & Okayama',
          'L7' => 'Naruto & Awaji',
          'F9' => 'Kouchi',
        }.freeze

        HEXES = {
          white: {
            %w[D3 H3 J3 B5 C8 E8 I8 D9 I10] => '',
            %w[F3 G4 H7 A10 J11 G12 E2 I2 K8 C10] => 'city=revenue:0',
            ['J5'] => 'town=revenue:0',
            %w[B11 G10 I12 J9] => 'town=revenue:0;icon=image:port',
            ['K6'] => 'upgrade=cost:80,terrain:water',
            %w[H5 I6] => 'upgrade=cost:80,terrain:water|mountain',
            %w[E4 D5 F5 C6 E6 G6 D7 F7 A8 G8 B9 H9 H11 H13] => 'upgrade=cost:80,terrain:mountain',
            ['I4'] => 'city=revenue:0;label=H;upgrade=cost:80',
          },
          yellow: {
            ['C4'] => 'city=revenue:20;path=a:2,b:_0',
            ['K4'] => 'city=revenue:30;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;label=T',
          },
          gray: {
            ['B7'] => 'city=revenue:40,slots:2;path=a:1,b:_0;path=a:3,b:_0;path=a:5,b:_0',
            ['B3'] => 'town=revenue:20;path=a:0,b:_0;path=a:_0,b:5',
            ['G14'] => 'town=revenue:20;path=a:3,b:_0;path=a:_0,b:4',
            ['J7'] => 'path=a:1,b:5',
          },
          red: {
            ['F1'] => 'offboard=revenue:yellow_30|brown_60|diesel_100;path=a:0,b:_0;path=a:1,b:_0',
            ['J1'] => 'offboard=revenue:yellow_20|brown_40|diesel_80;path=a:0,b:_0;path=a:1,b:_0',
            ['L7'] => 'offboard=revenue:yellow_20|brown_40|diesel_80;path=a:1,b:_0;path=a:2,b:_0',
          },
          green: {
            ['F9'] => 'city=revenue:30,slots:2;path=a:2,b:_0;path=a:3,b:_0;'\
                      'path=a:4,b:_0;path=a:5,b:_0;label=K;upgrade=cost:80,terrain:water',
          },
        }.freeze
      end
    end
  end
end
