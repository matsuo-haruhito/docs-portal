class DocumentVersionPreviewTargetDisplaySummary
  Result = Data.define(:classifications) do
    def present?
      classifications.any? { |classification| classification.role != :normal || classification.grouped? }
    end

    def primary
      classifications.select(&:primary?)
    end

    def attachments
      classifications.select(&:attachment?)
    end

    def hidden
      classifications.select(&:hidden?)
    end

    def debug
      classifications.select(&:debug?)
    end

    def grouped
      classifications.select(&:grouped?)
    end

    def normal
      classifications.select { |classification| classification.role == :normal }
    end

    def visible
      classifications.select(&:visible?)
    end

    def visible_ungrouped
      visible.reject(&:grouped?)
    end

    def groups
      grouped.group_by(&:group_name).sort.to_h
    end
  end

  def initialize(document_version, classifications: nil)
    @document_version = document_version
    @classifications = classifications
  end

  def call
    Result.new(classifications: classifications || DocumentVersionPreviewTargetClassifier.new(document_version).call)
  end

  private

  attr_reader :document_version, :classifications
end
