class DocumentsParameter < Rparam::Parameter
  INDEX_FILTERS = %i[q tag category document_kind visibility_policy has_html has_files has_pdf has_diagram page].freeze
  BOOLEAN_FILTERS = %i[has_html has_files has_pdf has_diagram].freeze

  def index
    param :q, type: String
    param :tag, type: String
    param :category, type: String, inclusion: Document.categories.keys
    param :document_kind, type: String, inclusion: Document.document_kinds.keys
    param :visibility_policy, type: String, inclusion: Document.visibility_policies.keys

    BOOLEAN_FILTERS.each do |name|
      param name, type: :boolean
    end

    param :page, type: Integer, min: 1, default: 1
  end
end
