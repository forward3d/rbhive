require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

puts RBHive.connect('hive.hadoop.forward.co.uk', 10001) {|db| 
  db.priority='VERY_LOW'
  
  p db.fetch %[
    SELECT * FROM uswitch_ppc_keywords where dated = '2010-11-15' order by keyword LIMIT 10
  ]
}
