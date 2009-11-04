require File.join(File.dirname(__FILE__), *%w[.. rbhive])

socket = Thrift::Socket.new("hadoopmaster.cluster.trafficbroker.co.uk", 10000)
transport = Thrift::BufferedTransport.new(socket)
protocol = Thrift::BinaryProtocol.new(transport)

client = ThriftHive::Client.new(protocol)

transport.open
begin
  # p client.methods.select {|m| !(m =~ /send|recv/)}
  client.execute("SELECT * FROM campaign_report")
  p client.get_fields("default", "campaign_report")
  p client.fetchN(10)[1]
  
rescue StandardError => e
  STDERR.puts(e)
ensure
  transport.close
end