module RBHive
  class ResultSet < Array
    def initialize(rows, schema)
      @schema = schema
      super(rows.map {|r| @schema.coerce_row(r) })
    end

    def column_names
      @schema.column_names
    end

    def column_type_map
      @schema.column_type_map
    end

    def to_csv(out_file=nil, opts={})
      to_seperated_output(",", out_file, opts)
    end

    def to_tsv(out_file=nil, opts={})
      to_seperated_output("\t", out_file, opts)
    end

    def as_arrays
      @as_arrays ||= self.map{ |r| @schema.coerce_row_to_array(r) }
    end

    private

    def to_seperated_output(sep, out_file, opts)
      rows = self.map { |r| @schema.coerce_row_to_array(r).join(sep) }
      rows.insert(0, separated_headers(sep)) if opts[:headers]
      sv = rows.join("\n")
      return sv if out_file.nil?
      File.open(out_file, 'w+') { |f| f << sv }
    end

    def separated_headers(sep)
      column_names.join(sep)
    end
  end
end
