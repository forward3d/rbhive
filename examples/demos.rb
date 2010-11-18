require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

puts RBHive.connect('hive.hadoop.forward.co.uk') {|db| 
  db.fetch %[SELECT * FROM uswitch_ppc_keywords where dated = '2010-11-15' LIMIT 10] 
}