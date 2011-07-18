module RBHive
  class SchemaDefinition
    attr_reader :schema
  
    TYPES = { 
      :boolean  => :to_s,
      :string   => :to_s,
      :bigint   => :to_i,
      :float    => :to_f,
      :double   => :to_f,
      :int      => :to_i,
      :smallint => :to_i,
      :tinyint  => :to_i,
    }
  
    def initialize(schema, example_row)
      @schema = schema
      @example_row = example_row ? example_row.split("\t") : []
    end
  
    def column_names
      @column_names ||= begin
        schema_names = @schema.fieldSchemas.map {|c| c.name.to_sym }
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
        definition = @schema.fieldSchemas.find {|s| s.name.to_sym == c }
        # If the column isn't in the schema (eg partitions in SELECT * queries) assume they are strings
        hsh[c] = definition ? definition.type.to_sym : :string
        hsh
      end
    end
  
    def coerce_row(row)
      column_names.zip(row.split("\t")).inject({}) do |hsh, (column_name, value)|
        hsh[column_name] = coerce_column(column_name, value)
        hsh
      end
    end
  
    def coerce_column(column_name, value)
      type = column_type_map[column_name]
      conversion_method = TYPES[type]
      conversion_method ? value.send(conversion_method) : value
    end
  
    def coerce_row_to_array(row)
      column_names.map { |n| row[n] }
    end
  end
end