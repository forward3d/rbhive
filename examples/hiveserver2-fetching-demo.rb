#!/usr/bin/env ruby

require 'rubygems'
require 'thrift'

GEM_ROOT = File.dirname(File.dirname(__FILE__))
require File.join(GEM_ROOT, 'lib', 'rbhive')

hive_server = ENV['HIVE_SERVER'] || 'localhost'
hive_port = (ENV['HIVE_PORT'] || 10_000).to_i

puts "Connecting to #{hive_server}:#{hive_port} using SASL..."
RBHive.tcli_connect(hive_server, :buffered, hive_port, nil) do |conn|
  puts "Fetching tables list..."
  tables = conn.fetch("SHOW TABLES")
  table_names = tables.map { |t| t[:tab_name] }
  puts "Tables: #{table_names.join(', ')}"
  puts

  hql = "SELECT * FROM daily_top_queries_report LIMIT 10"
  puts "Fetching a list of 10 queries in one go..."
  rows = conn.fetch(hql)
  puts "Fetched rows: #{rows.inspect}"
  puts

  hql = "SELECT * FROM daily_top_queries_report LIMIT 1111"
  puts "Fetching a list of 1111 queries in batches of up 100 rows..."
  conn.fetch_in_batch(hql, 100) do |batch|
    puts "Fetched #{batch.count} queries..."
  end
end
