# frozen_string_literal: true

require 'view/game/map'

module View
  class MapPage < Snabberb::Component
    needs :route

    ROUTE_FORMAT = %r{/map/([^/?]*)/?}.freeze

    def render
      game_title = @route.match(ROUTE_FORMAT)[1].gsub('%20', ' ')
      game = Engine.game_by_title(game_title)

      return h(:p, "Bad game title: #{game_title}") unless game

      players = Engine.player_range(game).max.times.map { |n| "Player #{n + 1}" }
      h(Game::Map, game: game.new(players), opacity: 1.0)
    end
  end
end
