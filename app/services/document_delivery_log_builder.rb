class DocumentDeliveryLogBuilder
  def initialize(sender:, project:, document: nil, document_set: nil, attributes: {})
    @sender = sender
    @project = project
    @document = document
    @document_set = document_set
    @attributes = attributes
  end

  def build
    validate_sender!
    validate_document!
    validate_document_set!

    DocumentDeliveryLog.new(default_attributes.merge(attributes))
  end

  def create!
    build.tap(&:save!)
  end

  private

  attr_reader :sender, :project, :document, :document_set, :attributes

  def validate_sender!
    raise ActiveRecord::RecordNotFound, "Project not found" unless project.viewable_by?(sender)
  end

  def validate_document!
    return if document.blank?
    raise ActiveRecord::RecordNotFound, "Document not found" unless document.project == project
    raise ActiveRecord::RecordNotFound, "Document not found" unless document.viewable_by?(sender)
  end

  def validate_document_set!
    return if document_set.blank?
    raise ActiveRecord::RecordNotFound, "Document set not found" unless document_set.project == project
    raise ActiveRecord::RecordNotFound, "Document set not found" unless document_set.viewable_by?(sender)
  end

  def default_attributes
    {
      project:,
      document:,
      document_set:,
      sender:,
      delivery_type: :portal_link,
      status: :draft
    }
  end
end
