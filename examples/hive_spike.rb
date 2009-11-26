require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') do |db|
  file = File.join(File.dirname(__FILE__), 'output.tsv')
  p db.fetch("SELECT COUNT(1) FROM keyword_reports")
end