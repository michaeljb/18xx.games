# frozen_string_literal: true

require_relative 'game_error'

module Engine
  module Spender
    def spender
      @spender || self
    end

    def spender=(entity)
      raise GameError, "Cannot set (#{name}).spender to a non-<Engine::Spender>" unless entity.spender?

      @spender = entity
    end

    def cash
      spender == self ? @cash : spender.cash
    end

    def debt
      spender == self ? (@debt || 0) : spender.debt
    end

    def permadebt
      spender == self ? (@permadebt || 0) : spender.permadebt
    end

    def spend(cash, receiver, check_cash: true, check_positive: true, borrow_from: nil)
      check_receiver(cash, receiver)

      unless spender == self
        return spender.spend(cash, receiver, check_cash: check_cash, check_positive: check_positive, borrow_from: borrow_from)
      end

      cash = cash.to_i
      self.check_cash(cash, borrow_from: borrow_from) if check_cash
      self.check_positive(cash) if check_positive

      # Check if we need to borrow from our borrow_from target
      if borrow_from && (cash > @cash)
        amount_borrowed = cash - @cash
        @cash = 0
        borrow_from.spender.cash -= amount_borrowed
      else
        @cash -= cash
      end

      receiver.spender.cash += cash
    end

    def set_cash(cash, other_spender)
      other_spender.spend(cash - self.cash, self, check_cash: false, check_positive: false)
    end

    def take_cash_loan(cash, bank, lender, interest: 0, permadebt: 0)
      bank.spend(cash, self)

      total_debt = cash + interest_amount(cash, interest)
      self.debt += total_debt
      lender.debt -= total_debt

      total_permadebt = interest_amount(cash, permadebt)
      self.permadebt += total_permadebt
      lender.permadebt -= total_permadebt

      [cash, total_debt, total_permadebt]
    end

    def take_interest(lender, interest: 0)
      added_interest = interest_amount(self.debt, interest)
      self.debt += added_interest
      lender.debt -= added_interest
      added_interest
    end

    def repay_cash_loan(bank, lender, payoff_amount: nil)
      amount = [payoff_amount || cash, self.debt].min

      spend(amount, bank)
      self.debt -= amount
      lender.debt += amount

      amount
    end

    def spender?
      true
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

    def debt=(amount)
      @debt = amount
    end

    def permadebt=(amount)
      raise GameError, 'Permadebt cannot be repaid' if !lender? && amount < self.permadebt

      @permadebt = amount
    end

    def lender?
      false
    end

    private

    def check_cash(amount, borrow_from: nil)
      available = @cash + (borrow_from ? borrow_from.cash : 0)
      raise GameError, "#{name} has #{@cash} and cannot spend #{amount}" if (available - amount).negative?
    end

    def check_positive(amount)
      raise GameError, "#{amount} is not valid to spend" unless amount.positive?
    end

    def check_receiver(cash, receiver)
      raise GameError, "Cash receiver must be a different entity: #{name}.spend(#{cash}, #{receiver.name})" if receiver == self
    end

    def interest_amount(amount, rate)
      (amount * rate / 100.0).ceil
    end
  end
end
