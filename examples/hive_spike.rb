require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') do |db|
  
  p db.fetch("SELECT * FROM campaign_report LIMIT 1")
  # p db.get_fields("default", "campaign_report")
end