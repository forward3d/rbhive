require "rubygems"
require "sinatra"
require File.join(File.dirname(__FILE__), *%w[connection])
require "haml"


get "/" do
  haml :index
end

post "/query" do
  query = params[:query]
  results = nil
  RBHive.connect('hadoopmaster.cluster.trafficbroker.co.uk') { |db| results = db.fetch(query) }
  haml :results, :locals => {:query => query, :results => results}
end


__END__

@@ layout
%html
  %head
    %title Hive Query
    %style{:type => "text/css", :media => "screen"}
      :plain
        table {
          border-collapse: collapse;
        }
        table td {
          text-align: left;
          vertical-align: top;
          border: 1px solid #ccc;
          padding: .5em;
        }
  %body
    = yield

@@ index
%form{ :action => '/query', :method => 'POST'}
  %textarea{ :name => 'query' }
  %input{ :type => 'submit' }
  
@@ results
%h1 Hive Results
%pre= query
%table
  - for row in results
    %tr
      - for col in row
        %td= col