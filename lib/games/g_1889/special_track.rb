# frozen_string_literal: true

if RUBY_ENGINE == 'opal'
else
  require_relative '../../engine/step/special_track'
  require_relative '../../engine/step/track_lay_when_company_sold'
end

module Engine
  module Step
    module G1889
      class SpecialTrack < SpecialTrack
        include TrackLayWhenCompanySold

        def process_lay_tile(action)
          return super unless action.entity == @company

          entity = action.entity
          ability = @game.abilities(@company, :tile_lay, time: 'sold')
          raise GameError, "Not #{entity.name}'s turn: #{action.to_h}" unless entity == @company

          lay_tile(action, spender: @round.company_sellers[@company])
          check_connect(action, ability)
          ability.use!

          @company = nil
        end
      end
    end
  end
end
