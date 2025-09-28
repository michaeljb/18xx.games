#!/usr/bin/env ruby

def multi_validate

  Dir['./models/**/*.rb'].sort.each { |file| require file }
  require './lib/engine'
  Sequel.extension :pg_json_ops
  DB.extension :pg_advisory_lock, :pg_json, :pg_enum
  DB.loggers[0].level = 3

  game_ids = Game.where(Sequel.pg_jsonb_op(:settings).has_key?('pin') => false, status: ['active','finished']).select_map(:id).shuffle
  groups = game_ids.each_slice(game_ids.size / (Etc.nprocessors - 1) + 1).to_a
  puts "#{groups.size} groups"
  DB.disconnect

  pids = []

  groups.each do |group|
    pids << Process.fork do
      time = Time.now
      broken = []
      group.each_slice(10).each do |ids|
        Game.eager(:user, :players, :actions).where(id: ids).all.each do |game|
          Engine::Game.load(game, strict: false).maybe_raise!
        rescue Exception => e
          broken << game.id
          puts "#{game.id}, #{game.title}, #{game.status}, #{e}"
        end
      end
      puts  "#{broken.size} / #{group.size} - #{Time.now - time}"
    end
  end

  puts "pids = #{pids}"

  pids.each { |pid| Process.waitpid(pid) }

  puts "finished"

end


# originally in validate.rb
def validate(process_count: nil, page_size: 100, strict: false, **kwargs)

  where_args = {
    Sequel.pg_jsonb_op(:settings).has_key?('pin') => false,
    status: %w[active finished]
  }.merge(kwargs)

  selected_ids = DB[:games].order(:id).where(**where_args).select(:id).all.map { |g| g[:id] }

  puts "found #{selected_ids.size} matching games"

  DB.disconnect

  slices = []

  process_count ||= Etc.nprocessors - 1
  puts "splitting game IDs into #{process_count} groups"

  process_count.times { slices << [] }
  selected_ids.each.with_index do |id, index|
    slices[index % process_count] << id
  end



  FileUtils.mkdir_p('validate')

  pids = []
  slices.each.with_index do |slice_ids, index|
    pids << Process.fork do
      data = {}
      slice_ids.each_slice(page_size) do |ids|
        Game.eager(:user, :players, :actions).where(id: ids).all.each do |game|
          data[game.id] = run_game(game, strict: strict)
        end
      end
      File.write("validate/validate_#{index}.json", JSON.pretty_generate(data))
    end
  end
  pids.each { |pid| Process.waitpid(pid) }

  data = {}
  (0..(slices.size - 1)).each do |index|
    data.merge!(JSON.parse(File.read("validate/validate_#{index}.json")))
  end

  total_games = selected_ids.size
  failed = data.count { |_id, g| g['exception'] }
  total_time = data.sum { |_id, g| g['time'] || 0 }
  avg_time = total_time / total_games

  puts "#{failed}/#{total_games} avg #{avg_time}"
  data['summary'] = {
    'failed': failed,
    'failed_ids': data.select { |id, g| g['exception'] }.map { |id, g| id.to_i }.sort,
    'total': total_games,
    'total_time': total_time,
    'avg_time': avg_time,
  }

  File.write("validate.json", JSON.pretty_generate(data))
end
