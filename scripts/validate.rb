# frozen_string_literal: true
# rubocop:disable all

require 'json'
require 'pp'

require_relative 'scripts_helper'
require_relative 'migrate_game'

# class to facilitate interacting with the results of validate_all() in an irb
# console
class Validate
  attr_reader :filename

  def merge_with!(filename)
    other_data = JSON.parse(File.read(filename)).except('processes').except('summary')

    @data = data
    if (common = data.keys & other_data.keys).size > 0
      raise Exeption, "cannot merge, found game IDs in common: #{common}"
    end
    @data.merge!(other_data)

    @data['summary'] = recompute_summary!

    write(@filename)
  end

  def inspect
    "#<#{self.class.name} @filename=#{@filename.inspect} @strict=#{strict} #{errors.size}/#{size}>"
  end

  def initialize(filename)
    @filename = filename
  end

  def write(filename)
    @filename = filename
    File.write(filename, JSON.pretty_generate(data))
  end

  def parsed
    @parsed ||= JSON.parse(File.read(filename))
  end

  def [](key)
    parsed[key]
  end

  def data
    @data ||= parsed.except('summary')
  end

  def size
    data.size
  end

  def summary
    @summary ||= parsed['summary'] || {}
  end

  def kwargs
    summary.key?('kwargs') ? summary['kwargs'] : {}
  end

  def strict
    kwargs.key?('strict') ? kwargs['strict'] : 'nil'
  end

  def clear_cache!
    @ids = nil
    @titles = nil
    @errors = nil
    @error_ids = nil
    @error_titles = nil
    @error_ids_by_title = nil
    @ids = nil
    @errors_really_broken = nil
    @ids_to_act_on = nil
  end

  def recompute_summary!
    clear_cache!

    total_games = ids.size
    total_time = data.sum { |_id, g| g['time'] || 0 }
    avg_time = total_time / total_games

    @summary = {
      'failed_ids' => error_ids,
      'failed' => errors.size,
      'total' => total_games,
      'total_time' => total_time,
      'avg_time' => avg_time,
    }
  end

  def ids
    @ids ||= data.keys.map(&:to_i)
  end

  def titles
    @titles ||= data.map { |_id, g| g['title'] }.uniq.sort
  end

  def non_errors
    @non_errors ||= data.reject { |_id, g| g['exception'] }
  end

  def errors
    @errors ||= data.select { |_id, g| g['exception'] }
  end

  def error_ids
    @error_ids ||= errors.keys.map(&:to_i)
  end

  def error_titles
    @error_titles ||= errors.map { |_id, g| g['title'] }.uniq.sort
  end

  def error_ids_by_title
    @error_ids_by_title ||=
      begin
        _errors = errors.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(id, game), obj|
          obj[game['title']] << game['id']
        end
        _errors.transform_values!(&:sort)
        _errors.sort_by { |t, _| t}.to_h
      end
  end

  def error_ids_by_title_pp
    error_ids_by_title.each do |title, ids|
      puts %("#{title}" => #{ids.to_s})
    end
    nil
  end

  def error_counts_by_title
    error_ids_by_title.transform_values(&:size)
  end

  def errors_really_broken
    @errors_really_broken ||= errors.select { |_id, g| !g['broken_action'] || g['exception'] !~ /GameError/ }
  end

  def ids_to_act_on
    @ids_to_act_on ||=
      begin
        _ids_to_act_on = {'archive' => [], 'pin' => []}
        error_ids_by_title.each do |title, ids|
          key = {
            prealpha: 'archive',
            alpha: 'archive',
            beta: 'pin',
            production: 'pin',
          }[Engine.meta_by_title(title)::DEV_STAGE]
          _ids_to_act_on[key].concat(ids)
        end
        _ids_to_act_on.transform_values!(&:sort!)
      end
  end

  def ids_to_pin
    ids_to_act_on['pin']
  end

  def ids_to_archive
    ids_to_act_on['archive']
  end

  def pin_and_archive!(pin_version)
    pin_games(pin_version, ids_to_pin)
    archive_games(ids_to_archive)
  end
end

$count = 0
$total = 0
$total_time = 0

def run_game(game, actions = nil, strict: false, silent: false, trace: false)
  actions ||= game.actions.map(&:to_h)
  data = {
    'id' => game.id,
    'title' => game.title,
    'optional_rules' => game.settings['optional_rules'],
    'status' => game.status
  }

  puts "running game #{game.id}" unless silent

  $total += 1
  time = Time.now
  begin
    engine = Engine::Game.load(game, strict: strict)
  rescue Exception => e # rubocop:disable Lint/RescueException
    $count += 1
    data['finished']=false
    data['exception']=e.inspect
    data['stack']=e.backtrace if trace
    return data
  end

  begin
    broken_action = engine.broken_action
    engine.maybe_raise!

    time = Time.now - time
    data['time'] = time
    $total_time += time
    data['finished']=true

    data['actions']=engine.actions.size
    data['result']=engine.result
  rescue Exception => e # rubocop:disable Lint/RescueException
    $count += 1
    data['url']="https://18xx.games/game/#{game.id}?action=#{engine.last_processed_action}"
    data['last_action']=engine.last_processed_action
    data['finished']=false
    data['exception']=e.inspect
    data['stack']=e.backtrace if trace
    data['broken_action']=broken_action&.to_h
  end
  data
end

def validate_all(*titles, families: true, game_ids: nil, strict: false, status: %w[active finished], filename: 'validate.json', silent: false)
  $count = 0
  $total = 0
  $total_time = 0
  page = []
  data = {}

  titles =
    if families
      titles.flat_map do |title|
        titles_for_game_family(title)
      end.uniq.sort
    else
      titles.sort
    end

  where_args = {Sequel.pg_jsonb_op(:settings).has_key?('pin') => false, status: status}
  where_args[:title] = titles unless titles.empty?
  where_args[:id] = game_ids if game_ids

  puts "Finding game IDS for #{where_args}"

  DB[:games].order(:id).where(**where_args).select(:id).paged_each(rows_per_fetch: 100) do |game|
    page << game
    if page.size >= 100
      where_args2 = {id: page.map { |p| p[:id] }}
      where_args2[:title] = titles unless titles.empty?
      games = Game.eager(:user, :players, :actions).where(**where_args2).all
      _ = games.each do |game|
        data[game.id]=run_game(game, strict: strict, silent: silent)
      end
      page.clear
    end
  end

  where_args3 = {id: page.map { |p| p[:id] }}
  where_args3[:title] = titles unless titles.empty?

  games = Game.eager(:user, :players, :actions).where(**where_args3).all
  _ = games.each do |game|
    data[game.id]=run_game(game, silent: silent)
  end
  puts "#{$count}/#{$total} avg #{$total_time / $total}"
  data['summary']={'failed':$count, 'total':$total, 'total_time':$total_time, 'avg_time':$total_time / $total}

  File.write(filename, JSON.pretty_generate(data))
  Validate.new(filename)
end

def validate(**kwargs)
  validate_kwargs = kwargs.dup

  _k = lambda do |key, default|
    if kwargs.include?(key)
      kwargs.delete(key)
    else
      default
    end
  end

  # ask user for confirmation if more than this many games will be processed
  prompt_threshold = _k.call(:prompt_threshold, 100)
  process_count = _k.call(:process_count, :max)
  fork_retries = _k.call(:fork_retries, 5)
  page_size = _k.call(:page_size, 10)
  strict = _k.call(:strict, true)
  # suppress "running game <id>" output for given titles, also validate related titles
  silent = _k.call(:silent, false)
  families = _k.call(:families, true)
  description = _k.call(:description, '')
  # include stack trace in JSON when error found
  trace = _k.call(:trace, true)
  show_slices = _k.call(:show_slices, false)
  only_slices = _k.call(:only_slices, [])
  # just return the game IDs sliced into subarrays, don't validate
  return_slices = _k.call(:return_slices, false)

  # remaining kwargs are forwared to the DB#where()

  lock_file = "validate/validate_#{description}.lock"
  if File.exist?(lock_file)
    puts "#{description}: found #{lock_file}"
    puts "#{description}: goodbye"
    return
  end

  FileUtils.mkdir_p('validate')
  File.write(lock_file, '')

  if kwargs[:title]
    if families
      kwargs[:title] = Array(kwargs[:title]).flat_map do |title|
        titles_for_game_family(title)
      end.uniq.sort
    end
  end

  pin_key = Sequel.pg_jsonb_op(:settings).has_key?('pin')
  where_kwargs = {
    pin_key => false,
    status: %w[active finished]
  }.merge(kwargs)
  puts "#{description}: Finding game IDS for:"
  pp where_kwargs.except(pin_key)

  selected_ids = DB[:games].order(:id).where(**where_kwargs).select(:id).all.map { |g| g[:id] }
  game_count = selected_ids.size
  puts "#{description}: Found #{game_count} matching games in range: #{selected_ids.minmax.join(' to ')}"

  # disconnect before starting connections in the forked processes
  DB.disconnect

  process_count =
    case process_count
    when :max
      [Etc.nprocessors - 1, game_count].min
    else
      [[[Etc.nprocessors - 1, process_count.to_i].min, 1].max, game_count].min
    end
  puts "#{description}: Will fork into #{process_count} processes" if process_count > 1 && !return_slices

  if prompt_threshold && game_count > prompt_threshold && !return_slices
    print "#{description}: Type #{game_count} to confirm you wish to proceed (with #{process_count} processes): "
    if gets.chomp.to_i != game_count
      puts "#{description}: User input did not match game count. Exiting valdiation."
      return FileUtils.rm(lock_file)
    end
  end

  slices = []
  process_count.times { slices << [] }
  selected_ids.each.with_index do |id, index|
    slices[index % process_count] << id
  end

  # only_slices
  if only_slices.size > 1
    filtered_slices = Array.new(process_count)
    only_slices.each do |slice|
      filtered_slices[slice] = slices[slice]
    end
    slices = filtered_slices
  end

  if return_slices
    FileUtils.rm(lock_file)
    return slices
  end

  pp slices if show_slices

  start_time = Time.now

  process_slices(slices, page_size, description, strict, silent, trace, fork_retries)

  end_time = Time.now

  data = combine_forked_data(description)

  total_games = selected_ids.size
  failed = data.count { |_id, g| g['exception'] }
  total_time = data.sum { |_id, g| g['time'] || 0 }
  avg_time = total_time / total_games

  data['summary'] = {
    'processes' => data.delete('processes'),
    'failed_ids' => data.select { |id, g| g['exception'] }.map { |id, g| id.to_i }.sort,
    'failed' => failed,
    'total' => total_games,
    'total_time' => total_time,
    'avg_time' => avg_time,
    'wall_time' => end_time - start_time,
    'kwargs' => validate_kwargs,
  }

  puts ''
  pp data['summary'].except('kwargs')

  File.write("validate_#{description}.json", JSON.pretty_generate(data))

  FileUtils.rm(lock_file)

  Validate.new("validate_#{description}.json")
end

def process_slices(slices, page_size, description, strict, silent, trace, fork_retries)
  pids = []
  slices.each.with_index do |slice_ids, index|
    next if slice_ids.nil?

    pids << Process.fork do
      @attempts = 0
      begin
        # spread out the forks attacking the database
        sleep(index)

        data = { 'processes' => { index => { 'finished' => false } } }
        File.write("validate/validate_#{description}_#{index}.json", JSON.pretty_generate(data))
        slice_ids.each_slice(page_size) do |ids|
          Game.eager(:user, :players, :actions).where(id: ids).all.each do |game|
            data[game.id] = run_game(game, strict: strict, silent: silent, trace: trace)
          end
        end
        data['processes'][index] = { 'finished': true }
        puts "\n#{description}: Process #{index} finished at #{Time.now.utc}\n\n"
        File.write("validate/validate_#{description}_#{index}.json", JSON.pretty_generate(data))
      rescue Exception => e
        @attempts += 1
        puts "\n#{description}: Process #{index} encountered an error at #{Time.now.utc}:\n#{e.inspect}\n\n"
        if @attempts < fork_retries
          # exponential backoff to retry
          sleep_time = 2**@attempts
          puts "\n#{description}: sleeping #{sleep_time} seconds then retrying "\
            "Process #{index}, attempt #{@attempts + 1}/#{fork_retries}...\n\n"
          sleep(sleep_time)
          retry
        end

        data = slice_ids.to_h do |id|
          [id, { 'exception': "see processes.#{index}.exception" }]
        end
        data['processes'] = {
          index => {'finished': false, 'exception' => e.inspect, 'stack' => e.backtrace },
        }
        File.write("validate/validate_#{description}_#{index}.json", JSON.pretty_generate(data))
      end
    end
  end
  pids.each { |pid| Process.waitpid(pid) }
end

def combine_forked_data(filename)
  data = { 'processes' => {}}

  files = Dir.glob("validate/validate_#{filename}_*.json").select do |f|
    File.basename(f) =~ /^validate_#{filename}_\d+.json$/
  end

  files.each do |f|
    forked_data = JSON.parse(File.read(f))
    data['processes'].merge!(forked_data.delete('processes'))
    data.merge!(forked_data)
  end

  data
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

def archive_games(game_ids)
  game_ids.each do |id|
    Game[id].archive!
  end
end

# returns Array<String> for all titles related to this one via DEPENDS_ON and
# GAME_VARIANTS connections
def titles_for_game_family(title)
  titles = Set.new

  meta = Engine.meta_by_title(title)
  top = meta
  top = Engine.meta_by_title(top::DEPENDS_ON) until top::DEPENDS_ON.nil?

  dependent_metas = Engine::GAME_METAS.group_by { |m| m::DEPENDS_ON }
  metas = [top, *dependent_metas[top.title]]

  until metas.empty?
    meta = metas.pop
    title = meta.title
    next if titles.include?(title)

    titles.add(title)
    meta::GAME_VARIANTS.each do |variant|
      metas << Engine.meta_by_title(variant[:title])
    end
    metas.concat(dependent_metas[title] || [])
  end

  titles.sort
end
