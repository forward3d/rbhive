require 'json'

module RBHive
  class TCLISchemaDefinition
    attr_reader :schema

    NAN = Float::NAN rescue 0.0/0.0
    INFINITY = Float::INFINITY rescue 1.0/0.0
    TYPES = {
      :boolean  => :to_s,
      :string   => :to_s,
      :float    => :to_f,
      :double   => :to_f,
      :int      => :to_i,
      :bigint   => :to_i,
      :smallint => :to_i,
      :tinyint  => :to_i,
    }

    def initialize(schema, example_row)
      @schema = schema
      @example_row = example_row ? example_row.colVals : []
    end

    def column_names
      @column_names ||= begin
        schema_names = @schema.columns.map {|c| c.columnName }

        # In rare cases Hive can return two identical column names
        # consider SELECT a.foo, b.foo...
        # in this case you get two columns called foo with no disambiguation.
        # as a (far from ideal) solution we detect this edge case and rename them
        # a.foo => foo1, b.foo => foo2
        # otherwise we will trample one of the columns during Hash mapping.
        s = Hash.new(0)
        schema_names.map! { |c| s[c] += 1; s[c] > 1 ? "#{c}---|---#{s[c]}" : c }
        schema_names.map! { |c| s[c] > 1 ? "#{c}---|---1" : c }
        schema_names.map! { |c| c.gsub('---|---', '_').to_sym }

        # Lets fix the fact that Hive doesn't return schema data for partitions on SELECT * queries
        # For now we will call them :_p1, :_p2, etc. to avoid collisions.
        offset = 0
        while schema_names.length < @example_row.length
          schema_names.push(:"_p#{offset+=1}")
        end
        schema_names
      end
    end

    def column_type_map
      @column_type_map ||= column_names.inject({}) do |hsh, c| 
        definition = @schema.columns.find {|s| s.columnName.to_sym == c }
        # If the column isn't in the schema (eg partitions in SELECT * queries) assume they are strings
        type = TYPE_NAMES[definition.typeDesc.types.first.primitiveEntry.type].downcase rescue nil
        hsh[c] = definition && type ? type.to_sym : :string
        hsh
      end
    end

    def coerce_row(row)
      column_names.zip(row.colVals.map(&:get_value).map(&:value)).inject({}) do |hsh, (column_name, value)|
        hsh[column_name] = coerce_column(column_name, value)
        hsh
      end
    end

    def coerce_column(column_name, value)
      type = column_type_map[column_name]
      return nil if value.nil?
      return INFINITY if (type != :string && value == "Infinity")
      return NAN if (type != :string && value == "NaN")
      return coerce_complex_value(value) if type.to_s =~ /^array/
      conversion_method = TYPES[type]
      conversion_method ? value.send(conversion_method) : value
    end

    def coerce_row_to_array(row)
      column_names.map { |n| row[n] }
    end

    def coerce_complex_value(value)
      return nil if value.nil?
      return nil if value.length == 0
      return nil if value == 'null'
      JSON.parse(value)
    end
  end
end
