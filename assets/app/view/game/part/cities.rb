# frozen_string_literal: true

require 'view/game/part/city'

module View
  module Game
    module Part
      class Cities < Base
        needs :show_revenue
        needs :graph, default: nil, store: true
        def render
          @tile.cities.map do |city|
            h(City, show_revenue: @show_revenue, region_use: @region_use, tile: @tile, city: city, graph: @graph)
          end
        end
      end
    end
  end
end
