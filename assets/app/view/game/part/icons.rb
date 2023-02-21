# frozen_string_literal: true

require 'view/game/part/base'
require 'view/game/part/small_item'

module View
  module Game
    module Part
      class Icons < Base
        include SmallItem

        needs :loc, default: nil

        ICON_RADIUS = 16
        DELTA_X = (ICON_RADIUS * 2) + 2

        def preferred_render_locations
          return preferred_render_locations_by_loc if @loc

          if layout == :pointy && @icons.one?
            POINTY_SMALL_ITEM_LOCATIONS
          elsif layout == :pointy
            POINTY_WIDE_ITEM_LOCATIONS
          elsif layout == :flat && @icons.one?
            SMALL_ITEM_LOCATIONS
          else
            WIDE_ITEM_LOCATIONS
          end
        end

        def preferred_render_locations_by_loc
          if layout == :pointy
            case @loc.to_s
            when '0.5'
              [PP_BOTTOM_LEFT_CORNER]
            when '1.5'
              [PP_UPPER_LEFT_CORNER]
            when '2.5'
              [PP_TOP_CORNER]
            when '3.5'
              [PP_UPPER_RIGHT_CORNER]
            when '4.5'
              [PP_BOTTOM_RIGHT_CORNER]
            when '5.5'
              [PP_BOTTOM_CORNER]
            else
              @loc = nil
              preferred_render_locations
            end
          else
            @loc = nil
            preferred_render_locations
          end
        end

        def load_from_tile
          @icons = @tile.icons.select { |i| !i.large && (i.loc == @loc) }
          @num_cities = @tile.cities.size
        end

        def render_part
          children = @icons.map.with_index do |icon, index|
            h(:image,
              attrs: {
                href: icon.image,
                x: ((index - ((@icons.size - 1) / 2.0)) * -DELTA_X).round(2),
                width: "#{ICON_RADIUS * 2}px",
                height: "#{ICON_RADIUS * 2}px",
              })
          end

          h(:g, { attrs: { transform: "#{rotation_for_layout} translate(#{-ICON_RADIUS} #{-ICON_RADIUS})" } }, [
              h(:g, { attrs: { transform: translate } }, children),
            ])
        end
      end
    end
  end
end
