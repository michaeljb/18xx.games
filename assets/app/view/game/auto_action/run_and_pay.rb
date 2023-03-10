# frozen_string_literal: true

require 'view/game/auto_action/base'

module View
  module Game
    module AutoAction
      class RunAndPay < Base
        needs :buy_corporation, store: true, default: nil

        def name
          "Run and Pay#{' (Enabled)' if @settings}"
        end

        def description
          'Automatically run the same routes as last OR and pay out. '\
          'All other OR actions are passed. If a better route becomes '\
          'available, it will not be run. If the route no longer becomes '\
          'legal before the selected time (e.g., due to a new token '\
          'placement), this will deactivate.'
        end

        # options
        # - until end of phase
        # - until end of game (or routes are not legal)

        # need to disable for specific corporation, not just general disable

        def render
          form = {}
          children = [h(:h3, name), h(:p, description)]

          if runnable.empty?
            children << h('p.bold', 'You are not president of any corporations, cannot program!')
            return children
          end

          children << h(:div, render_corporation_selector(form))
          children << h(Corporation, corporation: selected)

          first_radio = !checked?

          subchildren = [render_button(@settings ? 'Update' : 'Enable') { enable(form) }]
          subchildren << render_disable(@settings) if @settings
          children << h(:div, subchildren)

          children
        end

        # TODO: render corporations where user is president
        def render_corporation_selector(form)
          values = runnable.map do |entity|
            attrs = { value: entity.name }
            attrs[:selected] = true if selected == entity
            h(:option, { attrs: attrs }, entity.name)
          end
          buy_corp_change = lambda do
            corp = Native(form[:corporation]).elm&.value
            store(:buy_corporation, @game.corporation_by_id(corp))
          end

          [render_input('Corporation',
                        id: 'corporation',
                        el: 'select',
                        on: { input: buy_corp_change },
                        children: values, inputs: form)]
        end

        def enable(form)
          @settings = params(form)

          corporation = @game.corporation_by_id(@settings['corporation'])

          until_condition = conditions

          process_action(
            Engine::Action::ProgramRunAndPay.new(
              @sender,
              corporation: corporation,
              until_condition: @settings['until_condition'],
            )
          )
        end

        def checked?
          return :float if corp_settings&.until_condition == 'float'
          return :from_market if corp_settings&.from_market
          return :from_ipo if corp_settings

          nil
        end

        def selected
          @buy_corporation || @settings&.corporation || runnable.first
        end

        def corp_settings
          return unless selected == @settings&.corporation

          @settings
        end

        def runnable
          @game.corporations.select do |corp|
            corp.owner == @sender
          end
        end
      end
    end
  end
end
