require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

# CREATE TABLE:
# CREATE TABLE keyword_reports (line_date STRING, acctname STRING, campaign STRING, adgroup STRING, keyword STRING, adDistributionWithSearchPartners STRING, kwDestUrl STRING, currCode STRING, imps INT, clicks INT, cost INT, pos DOUBLE)
# PARTITIONED BY (import_date STRING, country STRING)
# ROW FORMAT DELIMITED 
#    FIELDS TERMINATED BY ',' 
#    LINES TERMINATED BY '\n'
# STORED AS TEXTFILE
# at br au 
countries = %w(at br au de es fr it nl no pl ru se uk us)

RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') do |db|
  
  countries.each do |country|

    (6..8).each do |day|
      padded_day = day.to_s.rjust(2, '0')
      
      file_date = "200911#{padded_day}"
      input_file = "/user/deploy/input/keyword-reports/#{country}-#{file_date}.csv"
      
      import_date = "2009-11-#{padded_day}"
      command = "LOAD DATA INPATH '#{input_file}' INTO TABLE keyword_reports PARTITION (import_date='#{import_date}', country='#{country}')"
      
      puts "Running #{command}"
      
      db.execute(command)
    end
    
  end
  
end