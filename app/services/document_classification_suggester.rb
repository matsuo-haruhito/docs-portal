class DocumentClassificationSuggester
  Suggestion = Data.define(:attributes, :matched_rules) do
    def empty?
      attributes.empty?
    end
  end

  DEFAULT_RULES_PATH = Rails.root.join("config", "document_classification_rules.yml")

  def initialize(rules_path: DEFAULT_RULES_PATH)
    @rules_path = Pathname(rules_path)
  end

  def suggest(source_path:, file_name: nil, frontmatter: {})
    attributes = {}
    matched_rules = []
    target_text = normalize_text([source_path, file_name].compact.join("/"))

    pattern_rules.each do |rule|
      pattern = normalize_text(rule.fetch("pattern"))
      next if pattern.blank?
      next unless target_text.include?(pattern)

      attributes.merge!(classification_attributes(rule))
      matched_rules << rule.fetch("name", rule.fetch("pattern"))
    end

    attributes.merge!(extension_attributes_for(file_name.presence || source_path))
    attributes.merge!(frontmatter_attributes(frontmatter))

    Suggestion.new(attributes:, matched_rules:)
  end

  private

  attr_reader :rules_path

  def config
    @config ||= if rules_path.file?
      YAML.safe_load(rules_path.read, aliases: false) || {}
    else
      {}
    end
  end

  def pattern_rules
    Array(config["rules"])
  end

  def extension_rules
    config["extension_rules"] || {}
  end

  def classification_attributes(rule)
    rule.slice("category", "document_kind", "visibility_policy", "snapshot_kind").symbolize_keys
  end

  def extension_attributes_for(path)
    extension = File.extname(path.to_s).delete_prefix(".").downcase
    extension_rules.fetch(extension, {}).symbolize_keys
  end

  def frontmatter_attributes(frontmatter)
    frontmatter
      .to_h
      .slice("category", "document_kind", "visibility_policy", "snapshot_kind")
      .compact
      .symbolize_keys
  end

  def normalize_text(value)
    value.to_s.unicode_normalize(:nfkc).strip.downcase
  end
end
