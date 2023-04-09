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

        def self.rotations(exits, sort: true)
          (0..5).map do |tick|
            rotated_exits = exits.map { |e| (e + tick) % 6 }
            sort ? rotated_exits.sort : rotated_exits
          end.uniq
        end

        def self.lane_permutations(num_segments)
          [2, nil].repeated_permutation(num_segments).to_a[..-2].sort_by { |x| x.count(2) }
        end

        # returns list of possible unique single-lane track tiles
        #
        # n = number of track segments
        def self.generate_exitses(n, valid_exits=[0,1,2,3,4,5])
          exitses = []
          combos = valid_exits.repeated_combination(n).to_a.reject { |c| c.uniq.size != c.size }

          combos.each do |exits|
            next if rotations(exits, sort: true).any? { |r| exitses.include?(r) }

            exitses << exits
          end

          exitses
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
          code = "city=revenue:yellow_30|green_40|brown_50,slots:2;label=TC;#{code}"
          code = "#{code};upgrade=cost:40,terrain:water"
          add_tile("#{id}TC", code, color='blue')
        end

        LOCATION_NAMES = {
          'A2' => 'Seattle',
          'B3' => 'Twin Cities',
          'B5' => 'Minocqua',
          'B9' => 'The Upper Peninsula',
          'C2' => 'Madison',
          'C6' => 'Wausau',
          'C8' => 'Green Bay',
          'C10' => 'Great Lakes',
          'D3' => 'La Crosse',
          'D9' => 'Milwaukee',
          'E4' => 'Elkhorn',
          'E6' => 'New Lisbon',
          'F1' => 'Rockford',
          'F9' => 'Kenosha',
          'G6' => 'Elgin',
          'H1' => 'Joliet',
          'H9' => 'North Chicago',
          'H11' => 'Chicago',
          'I2' => 'Sioux Falls',
        }.freeze

        HEXES = {
          white: {
            %w[D1 D5 E2 E8 E10 F5 F7 G2 G8 G10 H3 H5 H7] => '',
            %w[C2 F1 F9] => 'city=revenue:yellow_20|green_30|brown_40,slots:2',
            %w[C8] => 'city=revenue:yellow_20|green_30|brown_40,slots:2;label=GB',
            %w[C6 D3 H1] => 'city=revenue:yellow_20|green_30|brown_40',
            %w[D9] => 'city=revenue:yellow_20|green_60|brown_40,slots:4;label=M',
            %w[C4] => 'border=edge:2,type:impassable',
            %w[E6] => 'city=revenue:yellow_20|green_30|brown_40,slots:2;border=edge:3,type:impassable',
            %w[F3] => 'border=edge:5,type:impassable',
            %w[H9] => 'city=revenue:yellow_20|green_60|brown_40,slots:4',
          },
          blue: {
            ['B3'] => 'city=revenue:yellow_30|green_40|brown_50,slots:2;label=TC;upgrade=cost:40,terrain:water;border=edge:5,type:impassable',
            %w[D7] => 'upgrade=cost:40,terrain:water;border=edge:0,type:impassable',
            %w[G4] => 'upgrade=cost:40,terrain:water;border=edge:2,type:impassable',
          },
          yellow: {
            %w[E4] => 'city=revenue:green_40|brown_50,loc:2;city=revenue:green_40|brown_50,loc:5',
            %w[G6] => 'city=revenue:green_40|brown_50,loc:0;city=revenue:green_40|brown_50,loc:3',
          },
          red: {
            ['A2'] => 'offboard=revenue:yellow_30|green_40|brown_50|;path=a:5,b:_0',
            ['B5'] => 'offboard=revenue:yellow_20|green_20|brown_20;path=a:5,b:_0',
            ['B9'] => 'offboard=revenue:yellow_20|green_30|brown_40;path=a:0,b:_0',
            ['C10'] => 'offboard=revenue:yellow_20|green_40|brown_60;path=a:1,b:_0',
            ['H11'] => 'offboard=revenue:yellow_30|green_30|brown_60;path=a:1,b:_0,groups:Chicago;border=edge:0',
            ['I2'] => 'offboard=revenue:yellow_20|green_40|brown_60;path=a:2,b:_0',
            ['I10'] => 'offboard=revenue:yellow_30|green_30|brown_60,groups:Chicago,hide:1;path=a:2,b:_0;border=edge:3',
          },
        }.freeze
      end
    end
  end
end
