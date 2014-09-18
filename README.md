# RBHive - A Ruby Thrift client for Apache Hive

[![Code Climate](https://codeclimate.com/github/forward3d/rbhive/badges/gpa.svg)](https://codeclimate.com/github/forward3d/rbhive)

RBHive is a simple Ruby gem to communicate with the [Apache Hive](http://hive.apache.org)
Thrift servers.

It supports:
* Hiveserver (the original Thrift service shipped with Hive since early releases)
* Hiveserver2 (the new, concurrent Thrift service shipped with Hive releases since 0.10)
* Any other 100% Hive-compatible Thrift service (e.g. [Sharkserver](https://github.com/amplab/shark))

It is capable of using the following Thrift transports:
* BufferedTransport (the default)
* SaslClientTransport ([SASL-enabled](http://en.wikipedia.org/wiki/Simple_Authentication_and_Security_Layer) transport)
* HTTPClientTransport (tunnels Thrift over HTTP)

As of version 1.0, it supports asynchronous execution of queries. This allows you to submit
a query, disconnect, then reconnect later to check the status and retrieve the results.
This frees systems of the need to keep a persistent TCP connection. 

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

Hiveserver2 supports (in versions later than 0.12) asynchronous query execution. This
works by submitting a query and retrieving a handle to the execution process; you can
then reconnect at a later time and retrieve the results using this handle.
Using the asynchronous methods has some caveats - please read the Asynchronous Execution
section of the documentation thoroughly before using them.

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
* `:hive_version` - the number after the period in the Hive version; e.g. `10`, `11`, `12`, `13` or one of 
   a set of symbols; see [Hiveserver2 protocol versions](#hiveserver2-protocol-versions) below for details
* `:timeout` - if using BufferedTransport or SaslClientTransport, this is how long the timeout on the socket will be
* `:sasl_params` - if using SaslClientTransport, this is a hash of parameters to set up the SASL connection

If you pass either an empty hash or nil in place of the options (or do not supply them), the connection 
is attempted with the Hive version set to 0.10, using `:buffered` as the transport, and a timeout of 1800 seconds.

Connecting with the defaults:

    RBHive.tcli_connect('hive.server.address', 10_000) do |connection|
      connection.fetch('SHOW TABLES')
    end

Connecting with a Logger:

    RBHive.tcli_connect('hive.server.address', 10_000, { logger: Logger.new(STDOUT) }) do |connection|
      connection.fetch('SHOW TABLES')
    end

Connecting with a specific Hive version (0.12 in this case):

    RBHive.tcli_connect('hive.server.address', 10_000, { hive_version: 12 }) do |connection|
      connection.fetch('SHOW TABLES')
    end

Connecting with a specific Hive version (0.12) and using the `:http` transport:

    RBHive.tcli_connect('hive.server.address', 10_000, { hive_version: 12, transport: :http }) do |connection|
      connection.fetch('SHOW TABLES')
    end

We have not tested the SASL connection, as we don't run SASL; pull requests and testing are welcomed.

#### Hiveserver2 protocol versions

Since the introduction of Hiveserver2 in Hive 0.10, there have been a number of revisions to the Thrift protocol it uses.

The following table lists the available values you can supply to the `:hive_version` parameter when making a connection
to Hiveserver2.

| value   | Thrift protocol version | notes
| ------- | ----------------------- | -----
| `10`    | V1                      | First version of the Thrift protocol used only by Hive 0.10
| `11`    | V2                      | Used by the Hive 0.11 release (*but not CDH5 which ships with Hive 0.11!*) - adds asynchronous execution
| `12`    | V3                      | Used by the Hive 0.12 release, adds varchar type and primitive type qualifiers
| `13`    | V7                      | Used by the Hive 0.13 release, adds features from V4, V5 and V6, plus token-based delegation connections
| `:cdh4` | V1                      | CDH4 uses the V1 protocol as it ships with the upstream Hive 0.10
| `:cdh5` | V5                      | CDH5 ships with upstream Hive 0.11, but adds patches to bring the Thrift protocol up to V5

In addition, you can explicitly set the Thrift protocol version according to this table:

| value           | Thrift protocol version | notes
| --------------- | ----------------------- | -----
| `:PROTOCOL_V1`  | V1                      | Used by Hive 0.10 release
| `:PROTOCOL_V2`  | V2                      | Used by Hive 0.11 release
| `:PROTOCOL_V3`  | V3                      | Used by Hive 0.12 release
| `:PROTOCOL_V4`  | V4                      | Updated during Hive 0.13 development, adds decimal precision/scale, char type
| `:PROTOCOL_V5`  | V5                      | Updated during Hive 0.13 development, adds error details when GetOperationStatus returns in error state
| `:PROTOCOL_V6`  | V6                      | Updated during Hive 0.13 development, adds binary type for binary payload, uses columnar result set
| `:PROTOCOL_V7`  | V7                      | Used by Hive 0.13 release, support for token-based delegation connections

## Asynchronous execution with Hiveserver2

In versions of Hive later than 0.12, the Thrift server supports asynchronous execution.

The high-level view of using this feature is as follows:

1. Submit your query using `async_execute(query)`. This function returns a hash
   with the following keys: `:guid`, `:secret`, and `:session`. You don't need to
   care about the internals of this hash - all methods that interact with an async
   query require this hash, and you can just store it and hand it to the methods.
2. To check the state of the query, call `async_state(handles)`, where `handles`
   is the handles hash given to you when you called `async_execute(query)`.
3. To retrieve results, call either `async_fetch(handles)` or `async_fetch_in_batch(handles)`,
   which work like the non async methods.
4. When you're done with the query, call `async_close_session(handles)`.

### Memory leaks

When you call `async_close_session(handles)`, *all async handles created during this
session are closed*.

If you do not close the sessions you create, *you will leak memory in the Hiveserver2 process*.
Be very careful to close your sessions!

### Method documentation

#### `async_execute(query)`

This method submits a query for async execution. The hash you get back is used in the other
async methods, and will look like this:

    {
      :guid => (binary string),
      :secret => (binary string),
      :session => (binary string)
    }

The Thrift protocol specifies the strings as "binary" - which means they have no encoding.
Be *extremely* careful when manipulating or storing these values, as they can quite easily
get converted to UTF-8 strings, which will make them invalid when trying to retrieve async data.

#### `async_state(handles)`

`handles` is the hash returned by `async_execute(query)`. The state will be a symbol with
one of the following values and meanings:

| symbol                | meaning
| --------------------- | -------
| :initialized          | The query is initialized in Hive and ready to run
| :running              | The query is running (either as a MapReduce job or within process)
| :finished             | The query is completed and results can be retrieved
| :cancelled            | The query was cancelled by a user
| :closed               | Unknown at present
| :error                | The query is invalid semantically or broken in another way
| :unknown              | The query is in an unknown state
| :pending              | The query is ready to run but is not running

There are also the utility methods `async_is_complete?(handles)`, `async_is_running?(handles)`, 
`async_is_failed?(handles)` and `async_is_cancelled?(handles)`.

#### `async_cancel(handles)`

Calling this method will cancel the query in execution.

#### `async_fetch(handles)`, `async_fetch_in_batch(handles)`

These methods let you fetch the results of the async query, if they are complete. If you call
these methods on an incomplete query, they will raise an exception. They work in exactly the
same way as the normal synchronous methods.

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

We welcome contributions, issues and pull requests. If there's a feature missing in RBHive that you need, or you
think you've found a bug, please do not hesitate to create an issue.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
