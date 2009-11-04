require "rubygems"
require File.join(File.dirname(__FILE__), *%w[thrift thrift_hive])

module RBHive
  def connect(server, port=10_000)
    connection = RBHive::Connection.new(server, port)
    begin
      connection.open
      yield(connection)
    ensure
      connection.close
    end
  end
  module_function :connect
  
  class Connection
    attr_reader :client
    def initialize(server, port=10_000)
      @socket = Thrift::Socket.new(server, port)
      @transport = Thrift::BufferedTransport.new(@socket)
      @protocol = Thrift::BinaryProtocol.new(@transport)
      @client = ThriftHive::Client.new(@protocol)
    end
    
    def open
      @transport.open
    end
    
    def close
      @transport.close
    end
    
    def client
      @client
    end
    
    def execute(query)
      client.execute(query)
    end
    
    def fetch(query)
      execute(query)
      throw client.fetchAll.inspect
      client.fetchAll.map {|r| r.split("\t") }
    end
    
    def first(query)
      execute(query)
      client.fetchOne.split("\t")
    end
    
    def method_missing(meth, *args)
      client.send(meth, *args)
    end
  end
end

