class TableSchema
  attr_accessor :name
  attr_reader :columns, :partitions
  def initialize(name, comment=nil, options={}, &blk)
    @name, @comment = name, comment
    @location = options[:location] || nil
    @field_sep = options[:field_sep] || "\t"
    @line_sep = options[:line_sep] || "\n"
    @collection_sep = options[:collection_sep] || "|"
    @columns = []
    @partitions = []
    instance_eval(&blk) if blk
  end
  
  def column(name, type, comment=nil)
    @columns << Column.new(name, type, comment)
  end
  
  def partition(name, type, comment=nil)
    @partitions << Column.new(name, type, comment)
  end
  
  def create_table_statement()
    %[CREATE #{external}TABLE #{table_statement}
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '#{@field_sep}'
LINES TERMINATED BY '#{@line_sep}'
COLLECTION ITEMS TERMINATED BY '#{@collection_sep}'
STORED AS TEXTFILE
#{location}]
  end
  
  def replace_columns_statement
    alter_columns_statement("REPLACE")
  end
  
  def add_columns_statement
    alter_columns_statement("ADD")
  end
  
  def to_s
    table_statement
  end
  
  private

  def external
    @location.nil? ? '' : 'EXTERNAL '
  end
  
  def table_statement
    comment_string = (@comment.nil? ? '' : " COMMENT '#{@comment}'")
    %[`#{@name}` #{column_statement}#{comment_string}\n#{partition_statement}]
  end

  def location
    @location.nil? ? '' : "LOCATION '#{@location}'"
  end
  
  def alter_columns_statement(add_or_replace)
    %[ALTER TABLE `#{name}` #{add_or_replace} COLUMNS #{column_statement}]
  end
  
  def column_statement
    cols = @columns.join(",\n")
    "(\n#{cols}\n)"
  end
  
  def partition_statement
    return "" if @partitions.nil? || @partitions.empty?
    cols = @partitions.join(",\n")
    "PARTITIONED BY (\n#{cols}\n)"
  end
  
  class Column
    attr_reader :name, :type, :comment
    def initialize(name, type, comment=nil)
      @name, @type, @comment = name, type, comment
    end
    
    def to_s
      comment_string = @comment.nil? ? '' : " COMMENT '#{@comment}'"
      "`#{@name}` #{@type.to_s.upcase}#{comment_string}"
    end
  end
end
