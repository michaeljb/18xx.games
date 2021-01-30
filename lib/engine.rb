# frozen_string_literal: true

if RUBY_ENGINE == 'opal'
  require_tree 'engine/game'
else
  require 'require_all'
  require_rel 'engine/game'
end

module Engine
  @games = {}

  # Game or Meta
  GAMES = Game.constants.map do |c|
    klass = Game.const_get(c)

    if c.start_with?('G')
      if klass.is_a?(Class)
        klass
      elsif klass.is_a?(Module)
        klass::Meta
      end
    end
  end.compact

  # Game or Meta; all that are alpha or above
  VISIBLE_GAMES = GAMES.select { |game| %i[alpha beta production].include?(game::DEV_STAGE) }

  # Game or Meta
  GAMES_BY_TITLE = GAMES.map { |game| [game.title, game] }.to_h

  # Game only, not Meta; if called from Opal, the separately bundled game file
  # needs to have been imported by a <script>
  def self.game_by_title(title)
    return @games[title] if @games[title]
    return @games[title] = GAMES_BY_TITLE[title] if GAMES_BY_TITLE[title].is_a?(Class)

    get_game = lambda do
      require_tree 'engine/game'
      Engine::Game.constants
        .map { |c| Engine::Game.const_get(c) }
        .select { |c| c.constants.include?(:Game) }
        .map { |c| c.const_get(:Game) }
        .find { |c| c.title == title }
    end
    game = get_game.call

    # TODO: make sure this is the right place to load the script, might be best
    # to do it in game_manager
    # need to test with pins and hotseat
    if game.nil? && RUBY_ENGINE == 'opal'
      name = title.gsub(/(.)([A-Z])/, '\1_\2').downcase
      src = "/assets/g_#{name}.js"

      `var s = document.createElement('script');
       s.type = 'text/javascript';
       s.src = #{src};
       document.body.appendChild(s);`
      game = get_game.call
    end

    @games[title] = game
  end

  def self.player_range(game)
    game::PLAYER_RANGE || game::CERT_LIMIT.keys.minmax
  end
end
