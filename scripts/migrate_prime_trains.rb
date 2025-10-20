# frozen_string_literal: true

require 'json'

require_relative 'scripts_helper'
require_relative 'validate'

PRIME_TRAIN_REPLACEMENTS = {
  '1856' => {
    "2'-0" => {id: '2-5', variant: '2'},
    "3'-0" => {id: '3-4', variant: '3'},
    "4'-0" => {id: '4-3', variant: '4'},
    "5'-0" => {id: '5-2', variant: '5'},
  },
}.freeze

ACTIONS = {
  'buy_train' => 'train',
}

def migrate_prime_trains(ids)
  raise ArgumentError, "ids must be an Array" unless ids.is_a?(Array)

  where_args = {
    Sequel.pg_jsonb_op(:settings).has_key?('pin') => false,
    :status => %w[active finished],
    id: ids,
  }
  selected_ids = DB[:games].order(:id).where(**where_args).select(:id).all.map { |g| g[:id] }

  selected_ids.each do |id|
    db_game = ::Game[id]
    title = db_game.title
    next unless PRIME_TRAIN_REPLACEMENTS.include?(title)

    DB.transaction do
      actions_h = db_game.actions.map do |db_action|
        case db_action.action['type']
        when 'buy_train', 'discard_train', 'borrow_train'
          train_id = db_action.action['train']
          next db_action.to_h unless (new_train = PRIME_TRAIN_REPLACEMENTS[title][train_id])

          db_action.action['train'] = new_train[:id]
          db_action.action['variant'] = new_train[:variant]
          db_action.save

          db_action.to_h

        when 'run_routes'
          db_action.action['routes'].each do |route|
            train_id = route['train']
            next unless (new_train = PRIME_TRAIN_REPLACEMENTS[title][train_id])

            route['train'] = new_train[:id]
          end
          db_action.save
          db_action.to_h

        else
          db_action.to_h
        end
      end

      Engine::Game.load(db_game, actions: actions_h).maybe_raise!
    end
  end
end
