module Engine
  module Game
    module G1889
      module Step
        class BuySellParShares < Engine::Step::BuySellParShares
          def actions(entity)
            return [] unless entity == current_entity
            return ['sell_shares'] if must_sell?(entity)

            actions = []
            actions << 'buy_shares' if can_buy_any?(entity)
            actions << 'par' if can_ipo_any?(entity)
            actions << 'sell_shares' if can_sell_any?(entity)

            actions << 'pass' if !actions.empty? ||
                                 # block for Dougo railway exchange ability
                                 entity == @game.company_by_id('DR').owner
            actions
          end
        end
      end
    end
  end
end
