# RBHive -- Ruby thrift lib for executing Hive queries

RBHive is a simple Ruby gem to communicate with the [Apache Hive](http://hive.apache.org)
Thrift server.

It supports:
* Hiveserver (the original Thrift service shipped with Hive since early releases)
* Hiveserver2 (the new, concurrent Thrift service shipped with Hive releases since 0.10)
* Any other 100% Hive-compatible Thrift service (e.g. [Sharkserver](https://github.com/amplab/shark))

It is capable of using the following Thrift transports:
* BufferedTransport (the default)
* SaslClientTransport ([SASL-enabled](http://en.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer) transport)
* HTTPClientTransport (tunnels Thrift over HTTP)

## About Thrift services and transports

### Hiveserver

Hiveserver (the original Thrift interface) only supports a single client at a time. RBHive
implements this with the `RBHive::Connection` class. It only supports a single transport,
BufferedTransport.

### Hiveserver2

[Hiveserver2](https://cwiki.apache.org/confluence/display/Hive/Setting+up+HiveServer2) 
(the new Thrift interface) can support many concurrent client connections. It is shipped
with Hive 0.10 and later. In Hive 0.10, only BufferedTranport and SaslClientTransport are
supported; starting with Hive 0.12, HTTPClientTransport is also supported.

Each of the versions after Hive 0.10 has a slightly different Thrift interface; when
connecting, you must specify the Hive version or you may get an exception.

RBHive implements this client with the `RBHive::TCLIConnection` class.

#### Warning!

We had to set the following in hive-site.xml to get the BufferedTransport Thrift service
to work with RBHive:

    <property>
      <name>hive.server2.enable.doAs</name>
      <value>false</value>
    </property>

Otherwise you'll get this nasty-looking exception in the logs:

    ERROR server.TThreadPoolServer: Error occurred during processing of message.
    java.lang.ClassCastException: org.apache.thrift.transport.TSocket cannot be cast to org.apache.thrift.transport.TSaslServerTransport
      at org.apache.hive.service.auth.TUGIContainingProcessor.process(TUGIContainingProcessor.java:35)
      at org.apache.thrift.server.TThreadPoolServer$WorkerProcess.run(TThreadPoolServer.java:206)
      at java.util.concurrent.ThreadPoolExecutor$Worker.runTask(ThreadPoolExecutor.java:895)
      at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:918)
      at java.lang.Thread.run(Thread.java:662) 

### Other Hive-compatible services

Consult the documentation for the service, as this will vary depending on the service you're using.

## Connecting to Hiveserver and Hiveserver2

### Hiveserver

Since Hiveserver has no options, connection code is very simple:

    RBHive.connect('hive.server.address', 10_000) do |connection|
      connection.fetch 'SELECT city, country FROM cities'
    end 
    ➔ [{:city => "London", :country => "UK"}, {:city => "Mumbai", :country => "India"}, {:city => "New York", :country => "USA"}]

### Hiveserver2

Hiveserver2 has several options with how it is run. The connection code takes
a hash with these possible parameters:
* `:transport` - one of `:buffered` (BufferedTransport), `:http` (HTTPClientTransport), or `:sasl` (SaslClientTransport)
* `:hive_version` - the number after the period in the Hive version; e.g. `10`, `11`, `12`
* `:timeout` - if using BufferedTransport or SaslClientTransport, this is how long the timeout on the socket will be
* `:sasl_params` - if using SaslClientTransport, this is a hash of parameters to set up the SASL connection

If you pass either an empty hash or nil in place of the options (or do not supply them), the connection 
is attempted with the Hive version set to 0.10, using `:buffered` as the transport, and a timeout of 1800 seconds.

Connecting with the defaults:

    RBHive.tcli_connect('hive.server.address', 10_000) do |connection|
      connection.fetch('SHOW TABLES')
    end

Connecting with a specific Hive version (0.12 in this case):

    RBHive.tcli_connect('hive.server.address', 10_000, {:hive_version => 12}) do |connection|
      connection.fetch('SHOW TABLES')
    end

Connecting with a specific Hive version (0.12) and using the `:http` transport:

    RBHive.tcli_connect('hive.server.address', 10_000, {:hive_version => 12, :transport => :http}) do |connection|
      connection.fetch('SHOW TABLES')
    end 

We have not tested the SASL connection, as we don't run SASL; pull requests and testing are welcomed.

## Examples

### Fetching results

#### Hiveserver

    RBHive.connect('hive.server.address', 10_000) do |connection|
      connection.fetch 'SELECT city, country FROM cities'
    end 
    ➔ [{:city => "London", :country => "UK"}, {:city => "Mumbai", :country => "India"}, {:city => "New York", :country => "USA"}]

#### Hiveserver2

    RBHive.tcli_connect('hive.server.address', 10_000) do |connection|
      connection.fetch 'SELECT city, country FROM cities'
    end 
    ➔ [{:city => "London", :country => "UK"}, {:city => "Mumbai", :country => "India"}, {:city => "New York", :country => "USA"}]

### Executing a query

#### Hiveserver

    RBHive.connect('hive.server.address') do |connection|
      connection.execute 'DROP TABLE cities'
    end
    ➔ nil

#### Hiveserver2

    RBHive.tcli_connect('hive.server.address') do |connection|
      connection.execute 'DROP TABLE cities'
    end
    ➔ nil

### Creating tables

    table = TableSchema.new('person', 'List of people that owe me money') do
      column 'name', :string, 'Full name of debtor'
      column 'address', :string, 'Address of debtor'
      column 'amount', :float, 'The amount of money borrowed'

      partition 'dated', :string, 'The date money was given'
      partition 'country', :string, 'The country the person resides in'
    end

Then for Hiveserver:

    RBHive.connect('hive.server.address', 10_000) do |connection|
      connection.create_table(table)
    end  

Or Hiveserver2:

    RBHive.tcli_connect('hive.server.address', 10_000) do |connection|
      connection.create_table(table)
    end  

### Modifying table schema

    table = TableSchema.new('person', 'List of people that owe me money') do
      column 'name', :string, 'Full name of debtor'
      column 'address', :string, 'Address of debtor'
      column 'amount', :float, 'The amount of money borrowed'
      column 'new_amount', :float, 'The new amount this person somehow convinced me to give them'

      partition 'dated', :string, 'The date money was given'
      partition 'country', :string, 'The country the person resides in'
    end

Then for Hiveserver:

    RBHive.connect('hive.server.address') do |connection|
      connection.replace_columns(table)
    end  

Or Hiveserver2:

    RBHive.tcli_connect('hive.server.address') do |connection|
      connection.replace_columns(table)
    end  

### Setting properties

You can set various properties for Hive tasks, some of which change how they run. Consult the Apache
Hive documentation and Hadoop's documentation for the various properties that can be set. 
For example, you can set the map-reduce job's priority with the following:

    connection.set("mapred.job.priority", "VERY_HIGH")

### Inspecting tables

#### Hiveserver

    RBHive.connect('hive.hadoop.forward.co.uk', 10_000) {|connection| 
      result = connection.fetch("describe some_table")
      puts result.column_names.inspect
      puts result.first.inspect
    }

#### Hiveserver2

    RBHive.tcli_connect('hive.hadoop.forward.co.uk', 10_000) {|connection| 
      result = connection.fetch("describe some_table")
      puts result.column_names.inspect
      puts result.first.inspect
    }

## Testing

We use RBHive against Hive 0.10, 0.11 and 0.12, and have tested the BufferedTransport and
HTTPClientTransport. We use it against both Hiveserver and Hiveserver2 with success.

We have _not_ tested the SaslClientTransport, and would welcome reports
on whether it works correctly.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
