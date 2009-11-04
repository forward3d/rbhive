require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') do |db|
  file = File.join(File.dirname(__FILE__), 'output.tsv')
  db.fetch("SELECT * FROM keyword_reports LIMIT 100").to_tsv(file)
end