# frozen_string_literal: true

require_relative 'base'

module Engine
  module Ability
    class AssignHexes < Base
      attr_reader :hexes

      def setup(hexes:, passive: nil)
        @hexes = hexes
        @passive = passive || false
      end
    end
  end
end
