require 'rubygems'
require 'thrift'
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.tcli_connect("hive.hadoop.forward3d.com", 10_000, nil) do |connection|
  puts connection.fetch("SHOW TABLES")
end

table = RBHive::TableSchema.new('testing', 'Things') do
  column 'foo', :int, 'Value'
  column 'bar', :string, 'String value'
end

RBHive.tcli_connect("hive.hadoop.forward3d.com", 10_000, nil) do |connection|
  p connection.create_table(table)
  p connection.drop_table(table)
end
