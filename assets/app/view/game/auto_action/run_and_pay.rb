# frozen_string_literal: true

require 'view/game/auto_action/base'

module View
  module Game
    module AutoAction
      class RunAndPay < Base
        needs :current_corporation, store: true, default: nil
        needs :corporations, store: true, default: {}

        def name
          "Run and Pay#{' (Enabled)' if @settings}"
        end

        def description
          'Automatically run the same routes as last OR (as long as they are '\
          'legal) and pay out. All other OR actions are passed. If a better '\
          'route becomes available, this will not find it.'
        end

        # options
        # - until end of phase
        # - until end of game (or routes are not legal)

        # need to disable for specific corporation, not just general disable

        def render
          form = {}
          children = [h(:h3, name), h(:p, description)]

          if runnable.empty?
            children << h('p.bold', 'You are not president of any corporations with trains, cannot program!')
            return children
          end

          children << h(:div, render_corporation_selector(form))
          children << h(Corporation, corporation: selected)

          children << render_until_phase(form)
          children << render_until_end(form)

          subchildren = [render_button(@settings ? 'Update' : 'Enable') { enable(form) }]
          subchildren << render_disable(@settings) if @settings
          children << h(:div, subchildren)

          children
        end

        def render_radio(form, id, description, checked)
          checked =
            if (corp_id = @settings&.corporation)
              @settings['corporation'][corp_id] == :id
            end

          h(:div, [render_input(description,
                                id: id,
                                type: 'radio',
                                name: 'mode',
                                inputs: form,
                                attrs: {
                                  name: 'mode_options',
                                  checked: checked,
                                },
                               )])
        end

        def render_until_phase(form)
          checked =
            if (corp_id = @settings&.corporation)
              @settings['corporation'][corp_id] == :until_phase
            else
              true
            end

          render_radio(form, :until_phase, 'Run until end of current phase', checked)
        end

        def render_until_end(form)
          checked =
            if (corp_id = @settings&.corporation)
              @settings['corporation'][corp_id] != :until_phase
            else
              false
            end

          render_radio(form, :until_end, 'Run until end of game', checked)
        end

        # TODO: render corporations where user is president
        def render_corporation_selector(form)
          values = runnable.map do |entity|
            attrs = { value: entity.name }
            attrs[:selected] = true if selected == entity
            h(:option, { attrs: attrs }, entity.name)
          end
          run_and_pay_corp_change = lambda do
            corp = Native(form[:corporation]).elm&.value
            store(:current_corporation, @game.corporation_by_id(corp))
          end

          [render_input('Corporation',
                        id: 'corporation',
                        el: 'select',
                        on: { input: run_and_pay_corp_change },
                        children: values, inputs: form)]
        end

        def enable(form)
          @settings = params(form)

          puts "@settings = #{@settings}"

          # process_action(
          #   Engine::Action::ProgramRunAndPay.new(
          #     @sender,
          #     corporation: @game.corporation_by_id(@settings['corporation']),
          #     until_condition: until_condition,
          #   )
          # )
        end

        def until_condition
          return :until_phase if @settings['until_phase']
          return :until_end if @settings['until_end']

          nil
        end

        def selected
          @current_corporation || runnable.first
        end

        def corp_settings
          return unless selected == @settings&.corporation

          @settings
        end

        def runnable
          @game.corporations.select do |corp|
            corp.owner == @sender && !corp.trains.empty?
          end
        end
      end
    end
  end
end
