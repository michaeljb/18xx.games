# frozen_string_literal: true

require_relative 'entity'
require_relative 'spender'

module Engine
  class Lender
    include Entity
    include Spender

    def initialize
      @cash = 0
      @debt = 0
      @permadebt = 0
    end

    def lender?
      true
    end

    def name
      'Lender'
    end

    def inspect
      "<#{self.class.name}>"
    end
  end
end
