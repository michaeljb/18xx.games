# frozen_string_literal: true

require_relative 'base'
require_relative 'program_enable'

module Engine
  module Action
    class ProgramRunAndPay < ProgramEnable
      attr_reader :corporation, :until_condition

      def initialize(entity, corporation:, until_condition: false, phase: nil)
        super(entity)
        @corporation = corporation
        @until_condition = until_condition
        puts "ProgramRunAndPay#new"
        puts "    @until_condition = #{@until_condition}"

        @phase = phase if @until_condition == :phase
      end

      def self.h_to_args(h, game)
        {
          corporation: game.corporation_by_id(h['corporation']),
          until_condition: h['until_condition'],
          phase: h['phase'],
        }
      end

      def args_to_h
        {
          'corporation' => @corporation.id,
          'until_condition' => @until_condition,
          'phase' => @phase,
        }
      end

      def to_s
        until_condition = @until_condition == :phase ? 'next phase' : 'end of the game'
        "Run and pay for #{@corporation.name} until the #{until_condition}"
      end

      def disable?(game)
        @until_condition == :phase &&
          @phase != @game.phase.name
      end
    end
  end
end
