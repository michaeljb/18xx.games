# frozen_string_literal: true

require_relative '../g_1830/game'

module Engine
  module Game
    module GHiawathas
      module Trains
        TRAIN_COUNTS = {
          '2' => 4,
          '3' => 4,
          '4' => 3,
          '5' => 2,
          '6' => 2,
          'D' => 4,
        }.freeze
        TRAINS = G1830::Game::TRAINS.dup.map do |train|
          train[:num] = TRAIN_COUNTS[train[:name]]
          train
        end

        PHASE_TILES = {
          '2' => %i[blue white],
          '3' => %i[blue white yellow],
          '4' => %i[blue white yellow],
          '5' => %i[blue white yellow],
          '6' => %i[blue white yellow],
          'D' => %i[blue white yellow],
        }
        PHASES = G1830::Game::PHASES.dup.map do |phase|
          phase[:tiles] = PHASE_TILES[phase[:name]]
          phase
        end
      end
    end
  end
end
