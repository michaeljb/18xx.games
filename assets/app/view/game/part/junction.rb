# frozen_string_literal: true

module View
  module Game
    module Part
      class Junction < Snabberb::Component
        needs :color, default: 'black'

        # only render junctions when visualizing a Graph
        def render
          # easy/lazy mode: just take the existing hex and scale it down
          scale = 0.1

          stroke_width = 2
          scaled_stroke_width = stroke_width.to_f / scale

          polygon_props = {
            attrs: {
              points: Lib::Hex::POINTS,
              transform: "scale(#{scale})",
              fill: @color,
              stroke: 'white',
              'stroke-width': scaled_stroke_width,
            }
          }

          h(:polygon, polygon_props)
        end
      end
    end
  end
end
