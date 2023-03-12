# frozen_string_literal: true

require 'view/game/auto_action/base'

module View
  module Game
    module AutoAction
      class RunAndPay < Base
        needs :current_corporation, store: true, default: nil

        # @settings = programmed action

        def name
          corps = @settings.map { |s| s.corporation.id }.sort.join(', ')

          suffix =
            if corps.empty?
              ''
            else
              " (Enabled for #{corps})"
            end

          "Run and Pay#{suffix}"
        end

        def description
          'Automatically run the same routes as last OR (as long as they are '\
            'legal) and pay out. All other OR actions are passed. If a better '\
            'route becomes available, this will not find it.'
        end

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

          children << render_radio(form, :phase, 'Run until the next phase')
          children << render_radio(form, :end, 'Run until end of game')

          subchildren = [render_button(corp_settings ? "Update (#{selected.id})" : "Enable (#{selected.id})") { enable(form) }]
          subchildren << render_disable if corp_settings
          children << h(:div, subchildren)

          children
        end

        def corp_settings
          @settings.find { |s| s.corporation == selected }
        end

        def render_radio(form, id, description)
          h(:div, [render_input(description,
                                id: id,
                                type: 'radio',
                                name: 'mode',
                                inputs: form,
                                attrs: {
                                  name: 'mode_options',
                                  checked: id == :phase,
                                },)])
        end

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
          form_params = params(form)
          puts "form_params = #{form_params}"
          corp_id = form_params['corporation']
          condition = until_condition(form_params)

          process_action(
            Engine::Action::ProgramRunAndPay.new(
              @sender,
              corporation: @game.corporation_by_id(corp_id),
              until_condition: condition,
              current_phase: @game.phase.name,
            )
          )
        end

        def until_condition(form_params)
          return :phase if form_params['phase']
          return :end if form_params['end']

          nil
        end

        def selected
          @current_corporation || runnable.first
        end

        def runnable
          @game.corporations.select do |corp|
            corp.owner == @sender && !corp.trains.empty?
          end
        end

        def disable(corporation)
          process_action(
            Engine::Action::ProgramDisable.new(
              @sender,
              reason: 'user',
              original_type: @settings.first.type,
              corporation: corporation,
            )
          )
        end

        def render_disable
          corporation = selected
          render_button("Disable (#{corporation.id})") { disable(corporation) }
        end
      end
    end
  end
end
