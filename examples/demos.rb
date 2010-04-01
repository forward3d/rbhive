require "rubygems"
require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

puts RBHive.connect('master.hadoop.forward.co.uk') {|db| db.fetch "DESCRIBE uswitch_keywords" }.to_tsv