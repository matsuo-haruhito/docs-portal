class DocumentDeliveryLogBuilder
  def initialize(sender:, project:, document: nil, attributes: {})
    @sender = sender
    @project = project
    @document = document
    @attributes = attributes
  end

  def build
    validate_sender!
    validate_document!

    DocumentDeliveryLog.new(default_attributes.merge(attributes))
  end

  def create!
    build.tap(&:save!)
  end

  private

  attr_reader :sender, :project, :document, :attributes

  def validate_sender!
    raise ActiveRecord::RecordNotFound, "Project not found" unless project.viewable_by?(sender)
  end

  def validate_document!
    return if document.blank?
    raise ActiveRecord::RecordNotFound, "Document not found" unless document.project == project
    raise ActiveRecord::RecordNotFound, "Document not found" unless document.viewable_by?(sender)
  end

  def default_attributes
    {
      project:,
      document:,
      sender:,
      delivery_type: :portal_link,
      status: :draft
    }
  end
end
