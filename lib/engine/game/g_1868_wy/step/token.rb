# frozen_string_literal: true

require_relative '../../../step/token'
require_relative '../skip_coal_and_oil'

module Engine
  module Game
    module G1868WY
      module Step
        class Token < Engine::Step::Token
          include G1868WY::SkipCoalAndOil

          def help
            return unless @game.tokenless_dpr?(current_entity)

            if @round.num_laid_track.positive?
              'DPR must place its new home token in the newly opened city.'
            else
              'DPR may place its new home token in any open city.'
            end
          end

          def actions(entity)
            if @game.tokenless_dpr?(entity)
              @round.num_laid_track.positive? ? ['place_token'] : %w[place_token pass]
            else
              super
            end
          end

          def can_place_token?(entity)
            @game.tokenless_dpr?(entity) ? true : super
          end

          def check_connected(entity, _city, hex)
            if @game.tokenless_dpr?(entity)
              !hex.tile.paths.empty? && hex.tile.available_slot?
            else
              super
            end

            @game.tokenless_dpr?(entity) ? true : super
          end

          def tokener_available_hex(entity, hex)
            if @game.tokenless_dpr?(entity)
              !hex.tile.paths.empty? && hex.tile.available_slot?
            else
              super
            end
          end

          def process_place_token(action)
            action.entity.coordinates = action.city.hex.id if @game.tokenless_dpr?(action.entity)
            super
          end
        end
      end
    end
  end
end
