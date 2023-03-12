# frozen_string_literal: true

require_relative 'programmer'

module Engine
  module Step
    module ProgrammerRunAndPayPasser
      include Programmer

      def activate_program_run_and_pay(entity, _program)
        available_actions = actions(entity)

        if available_actions.include?('pass')
          [Action::Pass.new(entity)]
        else
          [Action::ProgramDisable.new(entity, reason: "could not pass #{description.downcase}")]
        end
      end
    end
  end
end
