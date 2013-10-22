require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.tcli_connect("hive.hadoop.forward3d.com", 10_002, :http, nil) do |connection|
  puts connection.fetch("select count(*) from gucci_keywords where dated='2013-01-01'")
end
