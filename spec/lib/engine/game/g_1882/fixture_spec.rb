# frozen_string_literal: true

require 'spec_helper'

module Engine
  module Game
    describe G1882 do
      describe 10_526 do
        it 'Saskatchewan Central is open before the first 6-train is purchased' do
          game = fixture_at_action(316)
          sc = game.company_by_id('SC')
          expect(sc.closed?).to eq(false)
        end

        it 'Saskatchewan Central closes when the first 6-train is purchased' do
          game = fixture_at_action(317)
          sc = game.company_by_id('SC')
          expect(sc.closed?).to eq(true)
        end
      end
    end
  end
end
