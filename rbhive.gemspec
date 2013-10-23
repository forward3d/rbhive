# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rbhive/version'

Gem::Specification.new do |spec|
  spec.name = "rbhive"
  spec.version = RBHive::VERSION
  spec.authors = ["Forward3D","KolobocK"]
  spec.description = "Simple gem for executing Hive queries and collecting the results"
  spec.summary = "Simple gem for executing Hive queries"
  spec.email = ["andy@forward.co.uk","kolobock@gmail.com", "developers@forward3d.com"]
  spec.homepage = %q{http://github.com/forward3d/rbhive}
  
  spec.files = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_dependency('thrift', '>= 0.9.0')
  spec.add_dependency('thin', '~> 1.5.1')
  spec.add_dependency('json')
end
