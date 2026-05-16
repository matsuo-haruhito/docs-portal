require "json"
require "yaml"

class DocumentFileStructuredPreview
  Result = Data.define(:formatted_text, :error) do
    def error?
      error.present?
    end
  end

  def initialize(file:, viewer_kind:)
    @file = file
    @viewer_kind = viewer_kind.to_sym
  end

  def call
    source = File.read(file.absolute_path, encoding: "UTF-8")

    case viewer_kind
    when :json
      value = JSON.parse(source)
      Result.new(formatted_text: JSON.pretty_generate(value), error: nil)
    when :yaml
      value = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
      Result.new(formatted_text: YAML.dump(value), error: nil)
    else
      Result.new(formatted_text: source, error: nil)
    end
  rescue JSON::ParserError, Psych::Exception, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    Result.new(formatted_text: nil, error: e.message)
  end

  private

  attr_reader :file, :viewer_kind
end
