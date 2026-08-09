# frozen_string_literal: true

module DocumentVersionQuality
  class ClassificationTagChecks
    def initialize(document_version:, check_class:)
      @document_version = document_version
      @check_class = check_class
    end

    def call
      checks = []
      checks << internal_content_without_tag_check if internal_content_without_tag?
      checks
    end

    private

    attr_reader :document_version, :check_class

    INTERNAL_ONLY_PATTERNS = DocumentVersionQualityChecker::INTERNAL_ONLY_PATTERNS
    MAX_READ_BYTES = 1.megabyte

    def internal_content_without_tag?
      return false unless document_version.document.document_tags.empty?

      markdown_files = document_version.document_files.select { |file| readable_markdown_file?(file) }
      return false if markdown_files.empty?

      markdown_files.any? do |file|
        content = read_markdown(file)
        next false if content.blank?

        INTERNAL_ONLY_PATTERNS.any? { |pattern| content.match?(pattern) }
      end
    end

    def readable_markdown_file?(file)
      file.effective_content_type.to_s.start_with?("text/markdown") && file.absolute_path&.file?
    rescue SystemCallError, IOError
      false
    end

    def read_markdown(file)
      File.binread(file.absolute_path, MAX_READ_BYTES).force_encoding(Encoding::UTF_8).scrub
    rescue SystemCallError, IOError
      nil
    end

    def internal_content_without_tag_check
      check_class.new(
        key: :classification_mismatch_internal_content,
        severity: :warning,
        message: "本文に社内限定を示す表現がありますが、分類タグが未設定です。",
        detail: "取り扱い注意の文書であれば分類タグの設定を検討してください。この警告は公開・ダウンロード判定には影響しません。"
      )
    end
  end
end
