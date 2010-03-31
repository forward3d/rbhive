require File.join(File.dirname(__FILE__), *%w[.. lib rbhive])

RBHive.connect('master.hadoop.forward.co.uk') do |db|
  db.execute "SELECT * FROM my_table"     # runs a query but ignores results
  results = db.fetch "DESCRIBE my_table"  # runs a query and returns results
  puts results.to_tsv
end