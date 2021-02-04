# frozen_string_literal: true

require_relative '../base'
require_relative 'config'
require_relative 'meta'
require_relative 'share_pool'
require_relative 'round/stock'

module Engine
  module Game
    module G18Chesapeake
      class Game < Game::Base
        register_colors(green: '#237333',
                        red: '#d81e3e',
                        blue: '#0189d1',
                        lightBlue: '#a2dced',
                        yellow: '#FFF500',
                        orange: '#f48221',
                        brown: '#7b352a')
        load_from_json(G18Chesapeake::Config::JSON)
        load_from_meta(G18Chesapeake::Meta)

        MUST_BID_INCREMENT_MULTIPLE = true
        ONLY_HIGHEST_BID_COMMITTED = true
        SELL_BUY_ORDER = :sell_buy

        def init_share_pool
          G18Chesapeake::SharePool.new(self)
        end

        def preprocess_action(action)
          case action
          when Action::LayTile
            queue_log! do
              check_special_tile_lay(action, baltimore)
              check_special_tile_lay(action, columbia)
            end
          end
        end

        def action_processed(action)
          case action
          when Action::LayTile
            flush_log!
          end
        end

        def stock_round
          G18Chesapeake::Round::Stock.new(self, [
                                            Step::DiscardTrain,
                                            Step::BuySellParShares,
                                          ])
        end

        def operating_round(round_num)
          Engine::Round::Operating.new(self, [
                                 Step::Bankrupt,
                                 Step::SpecialTrack,
                                 Step::BuyCompany,
                                 Step::Track,
                                 Step::Token,
                                 Step::Route,
                                 Step::Dividend,
                                 Step::DiscardTrain,
                                 Step::BuyTrain,
                                 [Step::BuyCompany, blocks: true],
                               ], round_num: round_num)
        end

        def setup
          cornelius.add_ability(Ability::Close.new(
                                  type: :close,
                                  when: 'bought_train',
                                  corporation: abilities(cornelius, :shares).shares.first.corporation.name,
                                ))

          return unless two_player?

          cv_corporation = abilities(cornelius, :shares).shares.first.corporation

          @corporations.each do |corporation|
            next if corporation == cv_corporation

            presidents_share = corporation.shares_by_corporation[corporation].first
            presidents_share.percent = 30

            final_share = corporation.shares_by_corporation[corporation].last
            @share_pool.transfer_shares(final_share.to_bundle, @bank)
          end
        end

        def status_str(corp)
          return unless two_player?

          "#{corp.presidents_percent}% President's Share"
        end

        def timeline
          @timeline = [
            'At the end of each set of ORs the next available non-permanent (2,3 or 4) train will be exported
           (removed, triggering phase change as if purchased)',
          ]
        end

        def check_special_tile_lay(action, company)
          abilities(company, :tile_lay, time: 'any') do |ability|
            hexes = ability.hexes
            next unless hexes.include?(action.hex.id)
            next if company.closed? || action.entity == company

            company.remove_ability(ability)
            @log << "#{company.name} loses the ability to lay #{hexes}"
          end
        end

        def columbia
          @companies.find { |company| company.name == 'Columbia - Philadelphia Railroad' }
        end

        def baltimore
          @companies.find { |company| company.name == 'Baltimore and Susquehanna Railroad' }
        end

        def cornelius
          @cornelius ||= @companies.find { |company| company.name == 'Cornelius Vanderbilt' }
        end

        def or_set_finished
          depot.export! if %w[2 3 4].include?(@depot.upcoming.first.name)
        end

        def float_corporation(corporation)
          super

          return unless two_player?

          @log << "#{corporation.name}'s remaining shares are transferred to the Market"
          bundle = ShareBundle.new(corporation.shares_of(corporation))
          @share_pool.transfer_shares(bundle, @share_pool)
        end
      end
    end
  end
end
