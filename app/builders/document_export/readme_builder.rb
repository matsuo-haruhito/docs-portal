module DocumentExport
  class ReadmeBuilder
    def initialize(lines:, empty_message:, pdf_items:)
      @lines = Array(lines)
      @empty_message = empty_message
      @pdf_items = Array(pdf_items)
    end

    def call
      content_lines = lines.dup

      if pdf_items.any?
        content_lines << ""
        content_lines << "PDF watermark metadata"
        pdf_items.each do |item|
          content_lines << "- #{item.output_file_name}: #{item.watermark_text}"
        end
      end

      if empty_message.present?
        content_lines << ""
        content_lines << empty_message
      end

      content_lines.join("\n") + "\n"
    end

    private

    attr_reader :lines, :empty_message, :pdf_items
  end
end
