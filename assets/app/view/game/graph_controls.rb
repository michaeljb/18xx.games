# frozen_string_literal: true

require 'lib/params'
require 'view/form'

module View
  module Game
    class GraphControls < Form
      module GraphVersion
        V2 = 'V2'
        V1 = 'V1'
      end

      # values are index of route_prop colors
      module Colors
        IN_GRAPH = 0
        CONNECTED_HEX = 0

        ENQUEUED = 1
        IN_GRAPH_AND_ENQUEUED = 2
        NEXT_IN_QUEUE = 3
        OVERLAPPING_PATH = 9

        LAYABLE_HEX = 9
      end

      needs :graph_v1, default: nil, store: true
      needs :graph_v2, default: nil, store: true
      needs :graph_viz_colors, default: nil, store: true
      needs :graph_version, default: GraphVersion::V2, store: true
      needs :game, default: nil, store: true
      needs :operator, default: nil, store: true

      def render
        return '' unless @game
        return '' unless Lib::Params['graph']

        all_operators = (@game.operating_order + @game.operated_operators).uniq.sort_by(&:name)

        graph_change = lambda do
          graph_version = Native(@graph_version_input).elm&.value
          operator_name = Native(@graph_input).elm&.value
          operator = all_operators.find { |o| o.name == operator_name }
          if operator
            case graph_version
            when GraphVersion::V1
              graph_v1 = Engine::Graph.new(@game)
              graph_v2 = nil
            else
              graph_v1 = Engine::BfsGraph::Adapter.new(@game)
              graph_v2 = graph_v1.corp_graphs[operator]
            end
          else
            graph_v1 = nil
            graph_v2 = nil
          end

          store(:operator, operator, skip: true)
          store(:graph_version, graph_version, skip: true)
          store(:graph_v1, graph_v1, skip: true)
          store(:graph_v2, graph_v2, skip: true)
          store(:graph_viz_colors, graph_viz_colors, skip: false)
        end

        graph_operators = all_operators.map do |operator|
          attrs = { value: operator.name }
          h(:option, { attrs: attrs }, operator.name)
        end
        graph_operators.unshift(h(:option, { attrs: {} }, 'None'))

        controls = []

        @graph_version_input = render_select(
          id: :graph_version,
          on: { input: graph_change },
          children: [GraphVersion::V2, GraphVersion::V1].map { |gt| h(:option, { attrs: { value: gt } }, gt) },
        )
        controls << h('label.inline-block', ['Graph Version:', @graph_version_input])

        @graph_input = render_select(id: :route, on: { input: graph_change }, children: graph_operators)
        controls << h('label.inline-block', ['Show Graph For:', @graph_input])

        controls = add_history_controls(controls) if @graph_v2

        h('div#graph_controls', controls)
      end

      def add_history_controls(controls)
        controls << render_button(
          '<<',
          lambda do
            store(:graph_v2, @graph_v2.reset!, skip: true)
            store(:graph_viz_colors, graph_viz_colors, skip: false)
          end,
          attrs: { disabled: @graph_v2.advanced.zero? },
        )

        controls << render_button(
          '<',
          lambda do
            store(:graph_v2, @graph_v2.reverse!, skip: true)
            store(:graph_viz_colors, graph_viz_colors, skip: false)
          end,
          attrs: { disabled: @graph_v2.advanced.zero? },
        )

        # not meant to be clickable, just show current step in graph processing
        controls << render_button(
          @graph_v2.advanced,
          nil,
          attrs: { disabled: true }
        )

        controls << render_button(
          '>',
          lambda do
            store(:graph_v2, @graph_v2.advance!, skip: true)
            store(:graph_viz_colors, graph_viz_colors, skip: false)
          end,
          attrs: { disabled: @graph_v2.finished? },
        )

        controls << render_button(
          '>>',
          lambda do
            store(:graph_v2, @graph_v2.advance_to_end!, skip: true)
            store(:graph_viz_colors, graph_viz_colors, skip: false)
          end,
          attrs: { disabled: @graph_v2.finished? },
        )

        @inputs ||= {}
        controls << render_input(
          '',
          id: :advance_to,
          input_style: { width: '64px' },
          placeholder: @graph_v2.advanced,
        )
        controls << render_button(
          'Go',
          lambda do
            store(:graph_v2, @graph_v2.jump_to!(params[:advance_to].to_i), skip: true)
            store(:graph_viz_colors, graph_viz_colors, skip: false)
          end,
        )

        controls
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

      def graph_viz_colors
        colors = {}

        if @graph_v2
          @graph_v2.visited.each { |atom, _| colors[atom] = Colors::IN_GRAPH }
          @graph_v2.queue.each do |q_item|
            atom = q_item[:atom]
            colors[atom] =
              if colors.include?(atom)
                Colors::IN_GRAPH_AND_ENQUEUED
              else
                Colors::ENQUEUED
              end
          end
          @graph_v2.overlapping_paths.each { |p| colors[p] = Colors::OVERLAPPING_PATH }
          if (next_in_queue = @graph_v2.peek)
            colors[next_in_queue] = Colors::NEXT_IN_QUEUE
          end
          @graph_v1.connected_hexes(@operator, advance_to_end: false).each { |h, _| colors[h] = Colors::LAYABLE_HEX }
          @graph_v1.reachable_hexes(@operator, advance_to_end: false).each { |h, _| colors[h] = Colors::CONNECTED_HEX }
        elsif @graph_v1
          @graph_v1.connected_nodes(@operator).each { |n, _| colors[n] = Colors::IN_GRAPH }
          @graph_v1.connected_paths(@operator).each { |p, _| colors[p] = Colors::IN_GRAPH }
          @graph_v1.connected_hexes(@operator).each { |h, _| colors[h] = Colors::LAYABLE_HEX }
          @graph_v1.reachable_hexes(@operator).each { |h, _| colors[h] = Colors::CONNECTED_HEX }
        end

        colors
      end
    end
  end
end
