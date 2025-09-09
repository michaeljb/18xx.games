# frozen_string_literal: true

require_relative 'game_error'

module Engine
  module Spender
    attr_writer :spender

    def spender
      @spender || self
    end

    def cash
      spender == self ? @cash : spender.cash
    end

    def check_cash(amount, borrow_from: nil)
      available = @cash + (borrow_from ? borrow_from.cash : 0)
      raise GameError, "#{name} has #{@cash} and cannot spend #{amount}" if (available - amount).negative?
    end

    def check_positive(amount)
      raise GameError, "#{amount} is not valid to spend" unless amount.positive?
    end

    def spend(cash, receiver, check_cash: true, check_positive: true, borrow_from: nil)
      unless spender == self
        return spender.spend(cash, receiver, check_cash: check_cash, check_positive: check_positive, borrow_from: borrow_from)
      end

      cash = cash.to_i
      check_cash(cash, borrow_from: borrow_from) if check_cash
      check_positive(cash) if check_positive

      # Check if we need to borrow from our borrow_from target
      if borrow_from && (cash > @cash)
        amount_borrowed = cash - @cash
        @cash = 0
        borrow_from.cash -= amount_borrowed
      else
        @cash -= cash
      end

      receiver.spender.cash += cash
    end

    def set_cash(cash, source)
      source.spend(cash - self.cash, self, check_cash: false, check_positive: false)
    end

    protected

    # This is protected so that only `spend()` can call this directly, to ensure
    # that no money is ever "dropped on the floor", or conjured from nothing
    # when The Bank should be used.
    def cash=(cash)
      if spender == self
        @cash = cash
      else
        spender.cash = cash
      end
    end
  end
end
