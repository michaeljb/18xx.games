# frozen_string_literal: true
# rubocop:disable all

require 'process'

require_relative 'models'

Dir['./models/**/*.rb'].sort.each { |file| require file }
Sequel.extension :pg_json_ops
require './lib/engine'
load 'migrate_game.rb'


$count = 0
$total = 0
$total_time = 0

def run_game(game, actions = nil, strict: false)
  actions ||= game.actions.map(&:to_h)
  data={'id':game.id, 'title': game.title, 'status':game.status}

  $total += 1
  time = Time.now
  engine = Engine::Game.load(game, strict: strict)
  begin
    engine.maybe_raise!

    time = Time.now - time

    $total_time += time
    data['finished']=true

    data['actions']=engine.actions.size
    data['result']=engine.result
  rescue Exception => e # rubocop:disable Lint/RescueException
    time = Time.now - time
    $count += 1
    data['url']="https://18xx.games/game/#{game.id}?action=#{engine.last_processed_action}"
    data['last_action']=engine.last_processed_action
    data['finished']=false
    #data['stack']=e.backtrace
    data['exception']=e
  end
  data['time'] = time
  data
end



def validate_all(*titles, game_ids: nil, strict: false)
  $count = 0
  $total = 0
  $total_time = 0
  page = []
  data = {}

  where_args = {Sequel.pg_jsonb_op(:settings).has_key?('pin') => false, status: %w[active finished]}
  where_args[:title] = titles if titles.any?
  where_args[:id] = game_ids if game_ids

  DB[:games].order(:id).where(**where_args).select(:id).paged_each(rows_per_fetch: 100) do |game|
    page << game
    if page.size >= 100
      where_args2 = {id: page.map { |p| p[:id] }}
      where_args2[:title] = titles if titles.any?
      games = Game.eager(:user, :players, :actions).where(**where_args2).all
      _ = games.each do |game|
        data[game.id]=run_game(game, strict: strict)
      end
      page.clear
    end
  end

  where_args3 = {id: page.map { |p| p[:id] }}
  where_args3[:title] = titles if titles.any?

  games = Game.eager(:user, :players, :actions).where(**where_args3).all
  _ = games.each do |game|
    data[game.id]=run_game(game)
  end
  puts "#{$count}/#{$total} avg #{$total_time / $total}"
  data['summary']={'failed':$count, 'total':$total, 'total_time':$total_time, 'avg_time':$total_time / $total}
  File.write("validate.json", JSON.pretty_generate(data))
end

def validate_one(id)
  game = Game[id]
  puts run_game(game)
end

def validate_migrated_one_mem(id)
  game = Game[id]
  puts run_game(game, migrate_db_actions_in_mem(game))
end
def validate_migrated_one(id)
  game = Game[id]
  puts run_game(game, migrate_db_actions(game))
end

def revalidate_broken(filename)
  $count = 0
  $total = 0
  $total_time = 0
  data = JSON.parse(File.read(filename))
  data = data.map do |game, val|
    if game != 'summary' && !val['finished'] && !val['pin']
      reload_game = Game[val['id']]
      d = run_game(reload_game, migrate_db_actions(reload_game))
      d['original']=val
      #[game,run_game(reload_game)]
      [game,d]
    end
  end.compact.to_h
  data['updated_summary']={'failed':$count, 'total':$total, 'total_time':$total_time, 'avg_time':$total_time / $total}
  File.write("revalidate.json", JSON.pretty_generate(data))
end

def validate_json(filename, strict: false)
  game = Engine::Game.load(filename, strict: strict)
  if game.exception
    puts game.broken_action.to_h
  end
  game.maybe_raise!
end

def validate_json_auto(filename, strict: false)
  # Validate the json, and try and add auto actions at the end
  data = JSON.parse(File.read(filename))
  rungame = Engine::Game.load(data, strict: strict).maybe_raise!
  rungame.maybe_raise!
  actions = rungame.class.filtered_actions(data['actions']).first

  action = actions.last

  # Process game to previous action
  auto_game = Engine::Game.load(data, at_action: action['id'] - 1)

  # Add the action but without the auto actions
  clone = action.dup
  clone.delete('auto_actions')
  auto_game.process_action(clone, add_auto_actions: true)
  auto_game.maybe_raise!
end

def pin_games(pin_version, game_ids)
  game_ids.each do |id|
    data = Game[id]
    if (pin = data.settings['pin'])
      puts "Game #{id} already pinned to #{pin}"
    else
      data.settings['pin'] = pin_version
    end
    data.save
  end
end

def validate(thread_count: 1, page_size: 100, strict: false, **kwargs)
  selected_ids = DB[:games].order(:id).where(**kwargs).select(:id).all.map { |g| g[:id] }

  slices = []
  thread_count.times { slices << [] }
  selected_ids.each.with_index do |id, index|
    slices[index % thread_count] << id
  end

  threads = []
  slices.each do |slice_ids|
    threads << Thread.new do
      data = {}

      slice_ids.each_slice(page_size) do |ids|
        games = Game.eager(:user, :players, :actions).where(id: ids).all
        games.each do |game|
          data[game.id] = run_game(game, strict: strict)
        end
      end

      data
    end
  end
  threads.each(&:join)
  data = threads.map(&:value).inject(&:merge)

  total_games = selected_ids.size
  failed = data.count { |_id, g| g['exception'] }
  total_time = data.sum { |_id, g| g['time'] || 0 }
  avg_time = total_time / total_games

  puts "#{failed}/#{total_games} avg #{avg_time}"
  data['summary'] = {'failed': failed, 'total': total_games, 'total_time': total_time, 'avg_time': avg_time}
  File.write("validate.json", JSON.pretty_generate(data))
end
