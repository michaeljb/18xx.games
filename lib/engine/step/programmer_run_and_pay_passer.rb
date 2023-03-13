# frozen_string_literal: true

require_relative 'programmer'

module Engine
  module Step
    module ProgrammerRunAndPayPasser
      include Programmer

      def auto_actions(entity)
        programmed_auto_actions(entity)
      end

      def activate_program_run_and_pay(entity, program)
        if program.corporation == entity && actions(entity).include?('pass')
          [Action::Pass.new(entity)]
        end
      end
    end
  end
end
