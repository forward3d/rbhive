require 'rubygems'
require 'thrift'
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.tcli_connect("hive.hadoop.forward3d.com", 10_000, nil) do |connection|
  puts connection.fetch("SHOW TABLES")
end
