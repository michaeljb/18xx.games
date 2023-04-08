# frozen_string_literal: true

require_relative '../g_1830/entities'

module Engine
  module Game
    module GHiawathas
      module Entities
        HOME_COORDINATES = {
          'B&O' => 'F3',
          'NYC' => 'G4',
          'PRR' => 'H7',
          'CPR' => 'A10',
          'C&O' => 'J11',
          'ERIE' => 'G12',
        }.freeze

        # use all the 1830 corporations except B&M and NYNH, give them homes for
        # the new map
        CORPORATIONS = G1830::Entities::CORPORATIONS.dup[0..5].map do |corp|
          corp[:coordinates] = HOME_COORDINATES[corp[:sym]]
          corp
        end
      end
    end
  end
end
