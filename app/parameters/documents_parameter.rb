class DocumentsParameter < Rparam::Parameter
  def index
    param :q, type: String
    param :tag, type: String
    param :page, type: Integer, min: 1, default: 1
  end
end
