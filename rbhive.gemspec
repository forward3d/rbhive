Gem::Specification.new do |s|
  s.name = "rbhive"
  s.version = "0.1.10"
  s.authors = ["Forward Internet Group"]
  s.date = %q{2010-11-24}
  s.description = "Simple lib for executing Hive queries"
  s.summary = "Simple lib for executing Hive queries"
  s.email = "andy@forward.co.uk"
  s.files = [
    "lib/rbhive.rb",
    "lib/rbhive/connection.rb",
    "lib/rbhive/schema.rb",
    "lib/thrift/facebook_service.rb",
    "lib/thrift/fb303_constants.rb",
    "lib/thrift/fb303_types.rb",
    "lib/thrift/hive_metastore_constants.rb",
    "lib/thrift/hive_metastore_types.rb",
    "lib/thrift/hive_service_constants.rb",
    "lib/thrift/hive_service_types.rb",
    "lib/thrift/queryplan_constants.rb",
    "lib/thrift/queryplan_types.rb",
    "lib/thrift/reflection_limited_constants.rb",
    "lib/thrift/reflection_limited_types.rb",
    "lib/thrift/serde_constants.rb",
    "lib/thrift/serde_types.rb",
    "lib/thrift/thrift_hive.rb",
    "lib/thrift/thrift_hive_metastore.rb"
  ]
  s.homepage = %q{http://github.com/trfficbroker/rbhive}
  s.require_paths = ["lib"]
  s.rubygems_version = "1.3.5"
  s.add_dependency('thrift', '>= 0.4.0')
end