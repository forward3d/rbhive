class ExplainResult
  def initialize(rows)
    @rows = rows
  end
  
  def ast
    by_section[:abstract_syntax_tree].first
  end
  
  def stage_count
    stage_dependencies.length
  end
  
  def stage_dependencies
    by_section[:stage_dependencies] || []
  end
  
  def to_tsv
    @rows.join("\n")
  end
  
  def raw
    @rows
  end
  
  def to_s
    to_tsv
  end
  
  private
  
  def by_section
    current_section = nil
    @rows.inject({}) do |sections, row|
      if row.match(/^[A-Z]/)
        current_section = row.chomp(':').downcase.gsub(' ', '_').to_sym
        sections[current_section] = []
      elsif row.length == 0
        next sections
      else
        sections[current_section] << row.strip
      end
      sections
    end
  end
end