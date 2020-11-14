# frozen_string_literal: true
# rubocop:disable all

require_relative 'models'

Dir['./models/**/*.rb'].sort.each { |file| require file }
Sequel.extension :pg_json_ops
require_relative 'lib/engine'

def switch_actions(actions, first, second)
  first_idx = actions.index(first)
  second_idx = actions.index(second)

  id = second['id']
  second['id'] = first['id']
  first['id'] = id

  actions[first_idx] = second
  actions[second_idx] = first
  return [first, second]
end

# Returns either the actions that are modified inplace, or nil if inserted/deleted
def repair(game, original_actions, actions, broken_action)
  optionalish_actions = %w[message buy_company]
  action_idx = actions.index(broken_action)
  action = broken_action['original_id'] || broken_action['id']
  puts "http://18xx.games/game/#{game.id}?action=#{action}"
  puts game.active_step
  prev_actions = actions[0..action_idx - 1]
  prev_action = prev_actions[prev_actions.rindex { |a| !optionalish_actions.include?(a['type']) }]
  next_actions = actions[action_idx + 1..]
  next_action = next_actions.find { |a| !optionalish_actions.include?(a['type']) }
  puts broken_action

  # issue #2032 only
  if game.class.title == '18GA'
    # new logic for token abilities doesn't present it as available if the hex
    # it can use is already occupied by the owning corporation, thus eliminating
    # the need for a manual pass on the token step when there isn't actually a
    # token action available
    if broken_action['type'] == 'pass' && game.active_step.is_a?(Engine::Step::Route)
      actions.delete(broken_action)
      return
    end
  elsif game.active_step.is_a?(Engine::Step::G1846::BuyCompany)
    pass = Engine::Action::Pass.new(game.active_step.current_entity).to_h
    actions.insert(action_idx, pass)
    return
  end

  puts "Game think it's #{game.active_step.current_entity.id} turn"
  raise Exception, "Cannot fix http://18xx.games/game/#{game.id}?action=#{action}"
end

def attempt_repair(actions)
  repairs = []
  rewritten = false
  ever_repaired = false
  loop do
    game = yield
    game.instance_variable_set(:@loading, true)
    # Locate the break
    repaired = false
    filtered_actions, _active_undos = game.class.filtered_actions(actions)
    filtered_actions.compact!

    filtered_actions.each.with_index do |action, _index|
      action = action.copy(game) if action.is_a?(Engine::Action::Base)
      begin
        game.process_action(action)
      rescue Exception => e
        puts e.backtrace
        puts "Break at #{e} #{action}"
        ever_repaired = true
        inplace_actions = repair(game, actions, filtered_actions, action)
        repaired = true
        if inplace_actions
          repairs += inplace_actions
        else
          rewritten = true
          # Added or moved actions... destroy undo states and renumber.
          filtered_actions.each_with_index do |a, idx|
            a['original_id'] = a['id'] unless a.include?('original_id')
            a['id'] = idx + 1
          end
          actions = filtered_actions
        end
        break
      end
    end

    break unless repaired
  end
  repairs = nil if rewritten
  return [actions, repairs] if ever_repaired
end

def migrate_data(data)
players = data['players'].map { |p| p['name'] }
  engine = Engine::GAMES_BY_TITLE[data['title']]
  begin
    data['actions'], repairs = attempt_repair(data['actions']) do
      engine.new(
        players,
        id: data['id'],
        actions: [],
      )
    end
  rescue Exception => e
    puts 'Failed to fix :(', e
    return data
  end
  fixed = true
  return data if fixed
end

# This doesn't write to the database
def migrate_db_actions_in_mem(data)
  original_actions = data.actions.map(&:to_h)

  engine = Engine::GAMES_BY_TITLE[data.title]
  begin
    actions, repairs = attempt_repair(original_actions) do
      engine.new(
        data.ordered_players.map(&:name),
        id: data.id,
        actions: [],
        optional_rules: data.settings['optional_rules']&.map(&:to_sym),
      )
    end
    puts repairs
    return actions || original_actions
  rescue Exception => e
    puts 'Something went wrong', e
    #raise e

  end
  return original_actions
end

def migrate_db_actions(data)
  original_actions = data.actions.map(&:to_h)
  engine = Engine::GAMES_BY_TITLE[data.title]
  begin
    actions, repairs = attempt_repair(original_actions) do
      engine.new(
        data.ordered_players.map(&:name),
        id: data.id,
        actions: [],
        optional_rules: data.settings['optional_rules']&.map(&:to_sym),
      )
    end
    if actions
      if repairs
        repairs.each do |action|
          # Find the action index
          idx = actions.index(action)
          data.actions[idx].action = action
          data.actions[idx].save
        end
      else # Full rewrite.
        DB.transaction do
          Action.where(game: data).delete
          game = engine.new(
            data.ordered_players.map(&:name),
            id: data.id,
            actions: [],
            optional_rules: data.settings['optional_rules']&.map(&:to_sym),
          )
          actions.each do |action|
            game.process_action(action)
            Action.create(
              game: data,
              user: data.user,
              action_id: game.actions.last.id,
              turn: game.turn,
              round: game.round.name,
              action: action,
            )
          end
        end
      end
    end
    return actions || original_actions
  rescue Exception => e
    puts 'Something went wrong', e
    puts "Pinning #{data.id}"
    pin = 'c91f8643'
    data.settings['pin']=pin
    data.save
  end
  return original_actions
end

def migrate_json(filename)
  data = migrate_data(JSON.parse(File.read(filename)))
  if data
    File.write(filename, JSON.pretty_generate(data))
  else
    puts 'Nothing to do, game works'
  end
end

def db_to_json(id, filename)
  game = Game[id]
  json = game.to_h(include_actions: true)

  File.write(filename, JSON.pretty_generate(json))
end

def migrate_db_to_json(id, filename)
  game = Game[id]
  json = game.to_h(include_actions: true)
  json['actions'] = migrate_db_actions(game)
  File.write(filename, JSON.pretty_generate(json))
end

def migrate_title(title)
  DB[:games].order(:id).where(Sequel.pg_jsonb_op(:settings).has_key?('pin') => false, status: %w[active finished], title: title).select(:id).paged_each(rows_per_fetch: 1) do |game|
    games = Game.eager(:user, :players, :actions).where(id: [game[:id]]).all
    games.each {|data|
      migrate_db_actions(data)
    }

  end
end

def migrate_all(game_ids: nil)
  where_args = {
    Sequel.pg_jsonb_op(:settings).has_key?('pin') => false,
    status: %w[active finished],
  }
  where_args[:id] = game_ids if game_ids

  DB[:games].order(:id).where(**where_args).select(:id).paged_each(rows_per_fetch: 1) do |game|
    games = Game.eager(:user, :players, :actions).where(id: [game[:id]]).all
    games.each {|data|
      migrate_db_actions(data)
    }

  end
end
