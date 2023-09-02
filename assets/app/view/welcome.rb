# frozen_string_literal: true

require 'lib/publisher'

module View
  class Welcome < Snabberb::Component
    needs :app_route, default: nil, store: true

    def render
      children = [render_notification]
      children << render_introduction
      children << render_buttons

      h('div#welcome.half', children)
    end

    def render_notification
      message = <<~MESSAGE
        <p>Michael Brandt's test server. Accounts here are separate from
        18xx.games. No email server is set up, so arrange some other channel
        (Discord, Slack, etc.) for turn notifications.</p>

        <p>Please do not share this URL unless you're my point of contact for
        testing an implementation while under development. Feel free to
        playtest any of the games here. Send me feedback via <a
        href="https://18xxgames.slack.com/" target="_blank">Slack</a>, <a
        href="mailto:michaelbrandt5+18xx@gmail.com">email</a>, or commenting on
        the GitHub issues:</p>
      MESSAGE

      props = {
        style: {
          background: 'rgb(240, 229, 140)',
          color: 'black',
          marginBottom: '1rem',
        },
        props: {
          innerHTML: message,
        },
      }

      h('div#notification.padded', props)
    end

    def render_introduction
      message = ''

      props = {
        style: {
          marginBottom: '1rem',
        },
        props: {
          innerHTML: message,
        },
      }

      h('div#introduction', props)
    end

    def render_buttons
      props = {
        style: {
          margin: '1rem 0',
        },
      }

      create_props = {
        on: {
          click: -> { store(:app_route, '/new_game') },
        },
      }

      tutorial_props = {
        on: {
          click: -> { store(:app_route, '/tutorial?action=1') },
        },
      }

      h('div#buttons', props, [
        h(:button, create_props, 'CREATE A NEW GAME'),
        h(:button, tutorial_props, 'TUTORIAL'),
      ])
    end
  end
end
