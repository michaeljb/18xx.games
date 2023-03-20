# frozen_string_literal: true

require_relative 'base'

module Engine
  module Step
    class Program < Base
      ACTIONS = %w[
        program_auction_bid
        program_buy_shares
        program_independent_mines
        program_merger_pass
        program_harzbahn_draft_pass
        program_share_pass
        program_close_pass
        program_disable
        program_run_and_pay
      ].freeze

      def actions(entity)
        return [] unless entity.player?

        ACTIONS
      end

      def process_program_auction_bid(action)
        process_program_enable(action)
      end

      def process_program_buy_shares(action)
        raise GameError, 'Until condition is unset' if !@game.loading && !action.until_condition

        process_program_enable(action)
      end

      def process_program_independent_mines(action)
        process_program_enable(action)
      end

      def process_program_merger_pass(action)
        process_program_enable(action)
      end

      def process_program_harzbahn_draft_pass(action)
        process_program_enable(action)
      end

      def process_program_share_pass(action)
        process_program_enable(action)
      end

      def process_program_close_pass(action)
        process_program_enable(action)
      end

      def process_program_enable(action)
        remove_programmed_action(action.entity, action.type)
        @game.player_log(action.entity, "Enabled programmed action '#{action}'")
        @game.programmed_actions[action.entity] << action
        @round.player_enabled_program(action.entity) if @round.respond_to?(:player_enabled_program)
      end

      def process_program_disable(action)
        return process_program_disable_run_and_pay(action) if action.original_type == Engine::Action::ProgramRunAndPay

        program = remove_programmed_action(action.entity, action.original_type)
        return unless program

        reason = action.reason || 'unknown reason'
        @game.player_log(action.entity, "Disabled programmed action '#{program}' due to '#{reason}'")
      end

      def process_program_run_and_pay(action)
        existing = @game.programmed_actions[action.entity].find do |a|
          a.type == action.type && a.corporation == action.corporation
        end
        @game.programmed_actions[action.entity].delete(existing) if existing

        @game.player_log(action.entity, "Enabled programmed action '#{action}'")
        @game.programmed_actions[action.entity] << action
        @round.player_enabled_program(action.entity) if @round.respond_to?(:player_enabled_program)
      end

      def process_program_disable_run_and_pay(action)
        existing = @game.programmed_actions[action.entity].find do |a|
          a.type == action.type && a.corporation == action.corporation
        end
        @game.programmed_actions[action.entity].delete(existing) if existing

        return unless existing

        reason = action.reason || 'unknown reason'
        @game.player_log(action.entity, "Disabled programmed action '#{program}' due to '#{reason}'")
        puts "Disabled programmed action '#{program}' due to '#{reason}'"
      end

      def remove_programmed_action(entity, type)
        existing = if type && @game.class::ALLOW_MULTIPLE_PROGRAMS
                     @game.programmed_actions[entity].find { |a| a.type == type }
                   else
                     @game.programmed_actions[entity].last # delete last added
                   end
        @game.programmed_actions[entity].delete(existing) if existing
        existing
      end

      def skip!; end

      def blocks?
        false
      end
    end
  end
end
