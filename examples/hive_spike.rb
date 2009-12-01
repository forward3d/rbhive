require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') do |db|
  puts db.fetch("SELECT engine, COUNT(1) FROM clicks GROUP BY engine").to_tsv
end