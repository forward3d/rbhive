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
      ResultSet.new(client.fetchAll)
    end
    
    def first(query)
      execute(query)
      ResultSet.new([client.fetchOne])
    end
    
    def method_missing(meth, *args)
      client.send(meth, *args)
    end
  end
  
  class ResultSet < Array
    def initialize(rows)
      super(rows.map {|r| r.split("\t") })
    end
    
    def to_csv(out_file=nil)
      output(",", out_file)
    end
    
    def to_tsv(out_file=nil)
      output("\t", out_file)
    end
    
    private
    
    def output(sep, out_file)
      tsv = self.map { |r| r.join("\t") }.join("\n")
      return tsv if out_file.nil?
      File.open(out_file, 'w') { |f| f << tsv }
    end
  end
end

