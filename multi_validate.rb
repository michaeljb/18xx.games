#!/usr/bin/env ruby

Dir['./models/**/*.rb'].sort.each { |file| require file }
require './lib/engine'
Sequel.extension :pg_json_ops
DB.extension :pg_advisory_lock, :pg_json, :pg_enum
DB.loggers[0].level = 3

game_ids = Game.where(Sequel.pg_jsonb_op(:settings).has_key?('pin') => false, status: ['active','finished']).select_map(:id).shuffle
groups = game_ids.each_slice(game_ids.size / (Etc.nprocessors - 1) + 1).to_a
puts "#{groups.size} groups"
DB.disconnect

groups.each do |group|
  Process.fork do
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
end; nil
