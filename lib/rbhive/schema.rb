class TableSchema
  attr_accessor :name
  attr_reader :columns, :partitions
  def initialize(name, comment=nil, field_sep='\t', line_sep='\n', &blk)
    @name, @comment, @field_sep, @line_sep = name, comment, field_sep, line_sep
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
    %[CREATE TABLE #{table_statement}
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '#{@field_sep}'
LINES TERMINATED BY '#{@line_sep}'
STORED AS TEXTFILE]
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
  
  def table_statement
    comment_string = (@comment.nil? ? '' : " COMMENT '#{@comment}'")
    %[`#{@name}` #{column_statement}#{comment_string}\n#{partition_statement}]
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