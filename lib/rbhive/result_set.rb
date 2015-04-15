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

    def to_csv(out_file=nil)
      to_separated_output(",", out_file)
    end

    def to_tsv(out_file=nil)
      to_separated_output("\t", out_file)
    end

    def as_arrays
      @as_arrays ||= self.map{ |r| @schema.coerce_row_to_array(r) }
    end

    private

    def to_separated_output(sep, out_file)
      rows = self.map { |r| @schema.coerce_row_to_array(r).join(sep) }
      sv = rows.join("\n")
      return sv if out_file.nil?
      File.open(out_file, 'w+') { |f| f << sv }
    end
  end
end
