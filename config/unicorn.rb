# frozen_string_literal: true

require_relative '../db'
require 'message_bus'

listen 9292
worker_processes 1
timeout 60
preload_app true

before_fork do |_server, _worker|
  DB.disconnect
end

after_fork do |_server, _worker|
  MessageBus.after_fork
end
