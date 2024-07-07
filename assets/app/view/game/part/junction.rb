# frozen_string_literal: true

require 'lib/settings'

module View
  module Game
    module Part
      class Junction < Snabberb::Component
        include Lib::Settings

        needs :graph_viz_colors, default: nil, store: true
        needs :junction, default: nil

        # easy/lazy mode: just scale down the existing hexagon shape
        SCALE = 0.1
        STROKE_WIDTH = 2
        ATTRS = {
          points: Lib::Hex::POINTS,
          transform: "scale(#{SCALE})",
          stroke: 'white',
          'stroke-width': STROKE_WIDTH.to_f / SCALE,
        }.freeze

        def render
          # junctions are only rendered when they are enqueued for processing
          # visualizing a Graph
         return '' unless (color_index = @graph_viz_colors&.[](@junction))

          h(:polygon,
            {
              attrs: {
                fill: route_prop(color_index, :color),
                **ATTRS,
              }
            })
        end
      end
    end
  end
end
