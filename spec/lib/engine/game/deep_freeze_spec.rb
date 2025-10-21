# frozen_string_literal: true

require './spec/spec_helper'

describe Engine::Game do
  SHOULD_BE_DEEPLY_FROZEN = [
    :COMPANIES,
    :CORPORATIONS,
    :HEXES,
    :LOCATION_NAMES,
    :MARKET,
    :MINORS,
    :OPTIONAL_RULES,
    :PHASES,
    :TILES,
    :TRAINS,
  ]

  MODULES = [
    :Entities,
    :Game,
    :Map,
    :Meta,
    :Trains,
  ].freeze

  game_modules = described_class.constants.filter_map do |const|
    game_module = Engine::Game.const_get(const)
    game_module.constants.include?(:Meta) && game_module.constants.include?(:Game) && game_module
  end

  game_modules.each do |game_module|
    describe game_module do
      SHOULD_BE_DEEPLY_FROZEN.each do |const|
        it "#{const} should be deeply frozen" do
          modules = [game_module, *MODULES.filter_map { |m| game_module.const_get(m) if game_module.constants.include?(m) } ]

          modules.each do |mod|
            if mod.constants.include?(const)
              expect(mod.const_get(const).deep_frozen?).to eq(true)
            end
          end
        end
      end
    end
  end
end
