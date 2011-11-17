require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hive.hadoop.forward.co.uk') {|db| 
  db.priority='VERY_LOW'
  
  result =  db.fetch %[
    describe mytable
  ]
  
  puts result.column_names.inspect
  puts result.first.inspect
}
