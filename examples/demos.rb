require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hive.hadoop.forward.co.uk') {|db| 
  db.priority='VERY_LOW'
  
  result =  db.fetch %[
    SELECT * FROM uswitch_ppc_keywords where dated = '2011-07-01' limit 2
  ]
  
  puts result.inspect
}
