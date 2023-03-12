# frozen_string_literal: true

require_relative 'base'

module Engine
  module Action
    class ProgramDisable < Base
      attr_reader :corporation, :reason, :original_type

      def initialize(entity, reason:, original_type: nil, corporation: nil)
        super(entity)
        @reason = reason
        @original_type = original_type
        @corporation = corporation
      end

      def self.h_to_args(h, game)
        {
          reason: h['reason'],
          original_type: h['original_type'],
          corporation: game.corporation_by_id(h['corporation']),
        }
      end

      def args_to_h
        {
          'reason' => @reason,
          'original_type' => @original_type,
          'corporation' => @corporation&.id,
        }
      end
    end
  end
end
