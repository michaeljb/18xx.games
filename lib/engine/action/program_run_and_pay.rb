# frozen_string_literal: true

require_relative 'base'
require_relative 'program_enable'

module Engine
  module Action
    class ProgramRunAndPay < ProgramEnable
      attr_reader :corporation, :until_phase

      def initialize(entity, corporation:, until_phase: false)
        super(entity)
        @corporation = corporation
        @until_phase = until_phase
      end

      def self.h_to_args(h, game)
        {
          corporation: game.corporation_by_id(h['corporation']),
          until_phase: h['until_phase'],
        }
      end

      def args_to_h
        {
          'corporation' => @corporation.id,
          'until_phase' => @until_phase,
        }
      end

      def to_s
        until_condition = @until_phase ? 'next phase' : 'end of the game'
        "Run and pay for #{@corporation.name} until the #{until_condition}"
      end

      def disable?(game)
        !game.round.stock?
      end
    end
  end
end
