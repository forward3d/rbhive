require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

puts RBHive.connect('hive.hadoop.forward.co.uk') {|db| 
  db.fetch %[DESCRIBE uswitch_ppc_keywords] 
}