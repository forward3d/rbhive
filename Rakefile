# frozen_string_literal: true

GENERATED_SOURCE_DIR = 'generated-source'
GENERATED_NAMESPACE = :HiveMetastore
HIVE_METASTORE_NAMESPACE = :HiveMetastore
SERDE_NAMESPACE = :Serde

require 'rake/clean'
CLOBBER.include 'pkg'

EXCLUSIONS = [
  '.git', '.gitignore',
  'Gemfile', 'Gemfile.lock',
  'pkg',
  GENERATED_SOURCE_DIR
].freeze

require 'rubygems/specification'
GEMSPEC = Gem::Specification.load(File.join(__dir__, 'rbhive.gemspec'))

require 'pathname'
def copy_source_files
  entries = Pathname.new(__dir__).children
  Dir.mkdir File.join(__dir__, GENERATED_SOURCE_DIR)
  entries.each do |f|
    unless EXCLUSIONS.include?(f.basename.to_s)
      FileUtils.cp_r f, File.join(GENERATED_SOURCE_DIR, f.basename)
    end
  end
end

module PlainName

  private

  def plain_name(node)
    if node.nil?
      [nil]
    elsif node.is_a? Symbol
      [node]
    elsif node.is_a? Parser::AST::Node
      case node.type
      when :const, :casgn
        plain_name(node.children[0]) + plain_name(node.children[1])
      when :cbase
        [:'::']
      else
        raise ArgumentError, "Unexpected node type: #{node.type}"
      end
    else
      raise ArgumentError, "Unexpected node class: #{node.class}"
    end
  end

  def plain_namespace(node)
    name = plain_name(node)
    if name.first.nil?
      (namespace || [:'::']) + name[1..-1]
    else
      name
    end
  end
end

require 'parser/current'
class NameTracker < Parser::AST::Processor
  include PlainName

  def initialize
    super
    @names = {}
    @namespace_stack = [[:'::']]
  end

  attr_reader :names

  def on_module(node)
    name, body = *node
    remember_name(name)
    namespace_stack.push plain_namespace(name)
    process(body)
    namespace_stack.pop
    node
  end

  def on_class(node)
    name, superclass, body = *node
    remember_name(name)
    remember_name(superclass) if superclass
    namespace_stack.push plain_namespace(name)
    process(body)
    namespace_stack.pop
    node
  end

  def on_casgn(node)
    remember_name(node)
    super node
  end

  private

  attr_reader :namespace_stack

  def namespace
    namespace_stack.last
  end

  def remember_name(node)
    plain_name = plain_name(node)
    plain_name =
      if plain_name.first.nil?
        namespace + plain_name[1..-1]
      else
        plain_name
      end
    plain_name.reduce(names) do |names, name|
      names[name] ||= {}
    end
  end
end

class RenamedConstDetector < Parser::AST::Processor
  include PlainName

  def initialize(names)
    @names = names
    @namespace_stack = [[:'::']]
    @renamed_consts = []
  end

  attr_reader :renamed_consts

  def on_module(node)
    name = node.children[0]
    namespace_stack.push plain_namespace(name)
    new_node = super(node)
    namespace_stack.pop
    new_node
  end

  def on_class(node)
    name = node.children[0]
    namespace_stack.push plain_namespace(name)
    new_node = super(node)
    namespace_stack.pop
    new_node
  end

  def on_const(node)
    new_namespace = namespace_for(node)
    if new_namespace
      renamed_consts << [node, new_namespace]
    else
      node
    end
  end

  private

  attr_reader :namespace_stack, :names

  def namespace
    namespace_stack.last
  end

  def namespace_for(node)
    name = plain_name(node)

    [
      HIVE_METASTORE_NAMESPACE,
      SERDE_NAMESPACE
    ].each do |generated_namespace|
      if name.first.nil?
        # Relative name
        namespace_stack.reverse_each do |namespace|
          renamed_name = [
            namespace[0],
            generated_namespace,
            *namespace[1..-1],
            *name[1..-1]
          ]
          found = renamed_name.reduce(names) do |names, segment|
            names ? names[segment] : names
          end
          return generated_namespace if found
        end
      elsif name.first == :'::'
        # Absolute name
        renamed_name = [
          name[0],
          generated_namespace,
          *name[1..-1]
        ]
        found = renamed_name.reduce(names) do |names, segment|
          names ? names[segment] : names
        end
        return generated_namespace if found
      end
    end
    nil
  end
end

def deep_merge_names(hash1, hash2)
  hash1.merge(hash2) do |_key, val1, val2|
    if val1.is_a?(Hash) && val2.is_a?(Hash)
      deep_merge_names(val1, val2)
    else
      val2
    end
  end
end

def namespace_file(filename, namespace)
  parser = Parser::CurrentRuby.new
  parser.builder.emit_file_line_as_literals = false

  source = File.read(filename).force_encoding(parser.default_encoding)

  source = "module #{namespace}\n#{source}\nend"
  File.write(filename, source)

  buffer = Parser::Source::Buffer.new(filename)
  buffer.source = source
  ast = parser.parse(buffer)

  name_tracker = NameTracker.new
  name_tracker.process(ast)

  name_tracker.names
end

def fix_thrift
  parser = Parser::CurrentRuby.new
  parser.builder.emit_file_line_as_literals = false
  names = {}

  Dir[File.join(__dir__, GENERATED_SOURCE_DIR, 'lib', 'thrift',
                'hive_metastore_{constants,types}.rb')]
    .each do |filename|
    names = deep_merge_names(
      names,
      namespace_file(filename, HIVE_METASTORE_NAMESPACE)
    )
  end

  Dir[File.join(__dir__, GENERATED_SOURCE_DIR, 'lib', 'thrift',
                'serde_{constants,types}.rb')]
    .each do |filename|
    names = deep_merge_names(
      names,
      namespace_file(filename, SERDE_NAMESPACE)
    )
  end

  names
end

def namespace_constants(filename, names, options = {})
  parser = Parser::CurrentRuby.new
  parser.builder.emit_file_line_as_literals = false
  parser.builder.class.emit_index = true

  source = File.read(filename).force_encoding(parser.default_encoding)
  buffer = Parser::Source::Buffer.new(filename)
  buffer.source = source

  ast = parser.parse(buffer)
  renamed_const_detector = RenamedConstDetector.new(names)
  renamed_const_detector.process(ast)

  renamed_const_detector
    .renamed_consts
    .sort_by { |node, _ns| node.location.expression.begin_pos }
    .reverse_each do |node, generated_namespace|
    range = Range.new(
      node.location.expression.begin_pos,
      node.location.expression.end_pos,
      true
    )
    const = source[range]
    new_const =
      if const[0, 2] == '::'
        "::#{generated_namespace}#{const}"
      else
        next if options[:absolute_only]
        "#{generated_namespace}::#{const}"
      end
    source[range] = new_const
  end
  File.write(filename, source)
end

def fix_rbhive(names)
  Dir[File.join(__dir__, GENERATED_SOURCE_DIR, 'lib', 'rbhive', '*.rb')]
    .each do |filename|
    namespace_constants(filename, names)
  end

  Dir[File.join(__dir__, GENERATED_SOURCE_DIR, 'lib', 'thrift', '*.rb')]
    .each do |filename|
    namespace_constants(filename, names, absolute_only: true)
  end
end

def prepare_source
  clean_up_generated_source
  copy_source_files
  new_names = fix_thrift
  fix_rbhive(new_names)
end

def clean_up_generated_source
  FileUtils.rm_r(GENERATED_SOURCE_DIR) if File.exist?(GENERATED_SOURCE_DIR)
end

def keep_gem
  built_gem_path =
    Dir[File.join(GENERATED_SOURCE_DIR, "#{GEMSPEC.name}-*.gem")]
    .max_by { |f| File.mtime(f) }

  file_name = File.basename(built_gem_path)
  FileUtils.mkdir_p('pkg')
  FileUtils.mv(built_gem_path, 'pkg')
  puts "#{GEMSPEC.name} #{GEMSPEC.version} built to pkg/#{file_name}"
end

def with_generated_source
  prepare_source
  Dir.chdir(GENERATED_SOURCE_DIR) do
    yield
  end
  keep_gem
ensure
  clean_up_generated_source unless ENV['PRESERVE_GENERATED']
end

desc "Build #{GEMSPEC.name}-#{GEMSPEC.version}.gem into the pkg directory."
task :build do
  with_generated_source do
    gem = ENV['BUNDLE_GEM'] || 'gem'
    system "#{gem} build -V #{GEMSPEC.name}.gemspec"
  end
end
