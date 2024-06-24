# frozen_string_literal: true

require 'lib/params'
require 'view/form'

module View
  module Game
    class GraphControls < Form
      needs :graph, default: nil, store: true
      needs :game, default: nil, store: true
      needs :operator, default: nil, store: true

      def render
        return '' unless @game
        return '' unless Lib::Params['graph']

        all_operators = (@game.operating_order + @game.operated_operators).uniq.sort_by(&:name)

        graph_change = lambda do
          operator_name = Native(@graph_input).elm&.value
          operator = all_operators.find { |o| o.name == operator_name }
          if operator
            graph = @game.bfs_graphs[operator]
            store(:operator, operator, skip: true)
            store(:graph, graph)
          else
            store(:operator, nil, skip: true)
            store(:graph, nil)
          end
        end

        graph_operators = all_operators.map do |operator|
          attrs = { value: operator.name }
          h(:option, { attrs: attrs }, operator.name)
        end
        graph_operators.unshift(h(:option, { attrs: {} }, 'None'))

        controls = []

        @graph_input = render_select(id: :route, on: { input: graph_change }, children: graph_operators)
        controls << h('label.inline-block', ['Show Graph For:', @graph_input])

        return h('div#graph_controls', controls) unless @graph

        controls << render_button(
          '<<',
          -> { store(:graph, @graph.reset!) },
          attrs: {disabled: @graph.advanced.zero?},
        )

        controls << render_button(
          '<',
          -> { store(:graph, @graph.reverse!) },
          attrs: {disabled: @graph.advanced.zero?},
        )

        # not meant to be clickable, just show current step in graph processing
        controls << render_button(
          @graph.advanced,
          nil,
          attrs: {disabled: true}
        )

        controls << render_button(
          '>',
          -> { store(:graph, @graph.advance!) },
          attrs: {disabled: @graph.finished?},
        )

        controls << render_button(
          '>>',
          -> { store(:graph, @graph.advance_to_end!) },
          attrs: {disabled: @graph.finished?},
        )

        @inputs ||= {}
        controls << render_input(
          '',
          id: :advance_to,
          input_style: {width: '64px'},
          placeholder: @graph.advanced,
        )
        controls << render_button(
          'Go',
          -> { store(:graph, @graph.jump_to!(params[:advance_to].to_i)) },
        )

        h('div#graph_controls', controls)
      end

      def render_select(id:, on: {}, children: [])
        input_props = {
          attrs: {
            id: id,
          },
          on: { **on },
        }
        h(:select, input_props, children)
      end

      def render_button(text, action, **props)
        props = {
          on: {
            click: action,
          },
          **props,
        }

        h('button.small', props, text)
      end
    end
  end
end
