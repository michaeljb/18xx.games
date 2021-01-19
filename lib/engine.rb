# frozen_string_literal: true

if RUBY_ENGINE == 'opal'
  require_tree 'engine/game'
else
  require 'require_all'
  require_rel 'engine/game'
end

module Engine
  #  GAMES = Game.constants.map do |c|
  #    klass = Game.const_get(c)
  #    next if !klass.is_a?(Class) || klass == Game::Base
  #
  #  klass
  # end.compact

  # Games that are alpha or above
  # VISIBLE_GAMES = GAMES.select { |game| %i[alpha beta production].include?(game::DEV_STAGE) }

  # GAMES_BY_TITLE = GAMES.map { |game| [game.title, game] }.to_h

  def self.game_by_title(title)
    if RUBY_ENGINE != 'opal'
      require 'require_all'
      require_rel 'games'
    end

    game_const = Game.constants.find do |c|
      klass = Game.const_get(c)
      next if !klass.is_a?(Class) || klass == Game::Base

      klass.title == title
    end

    game = Game.const_get(game_const)

    puts "found game class: #{game.title}"

    game
  end

  def self.player_range(game)
    game::CERT_LIMIT.keys.minmax
  end
end
