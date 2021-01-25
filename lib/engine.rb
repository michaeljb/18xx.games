# frozen_string_literal: true

if RUBY_ENGINE == 'opal'
  require_tree 'engine/game'
else
  require 'require_all'
  require_rel 'engine/game'
end

module Engine
  @games = {}

  GAMES = Game.constants.map do |c|
    klass = Game.const_get(c)
    next if !klass.is_a?(Class) || klass == Game::Base
    klass
  end.compact

  # Games that are alpha or above
  # GAME_PUBLISHER
  VISIBLE_GAMES = GAMES.select { |game| %i[alpha beta production].include?(game::DEV_STAGE) }

  GAMES_BY_TITLE = GAMES.map { |game| [game.title, game] }.to_h

  def self.game_by_title(title)
    return @games[title] if @games.key?(title)

    if RUBY_ENGINE == 'opal'
      require "g_#{title}/game"
    else
      require_all Dir.glob("lib/engine/**/game.rb").select { |f| File.dirname(f) =~ %r{/g_} }
    end

    puts 'hello there'

    games = GAMES.dup
    games.concat(Engine.constants.select { |c| c =~ /^G18/ }.map { |c| Engine.const_get(c) }
                   .flat_map { |c| c.constants.select { |cc| cc == :Game }.map { |cc| c.const_get(cc)} })

    puts 'general kenobi'
    game = games.find { |c| c.title == title }

    puts "game = #{game}"

    puts "G1889 = #{Engine::G1889::Game}"

    @games[title] = game
  end

  def self.player_range(game)
    game::CERT_LIMIT.keys.minmax
  end
end
