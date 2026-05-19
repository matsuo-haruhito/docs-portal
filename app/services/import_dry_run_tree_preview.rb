class ImportDryRunTreePreview
  Row = Struct.new(:path, :label, :depth, :change_type, :source, keyword_init: true)

  def initialize(dry_run)
    @dry_run = dry_run
  end

  def call
    {
      before_rows: build_rows(existing_paths, {}),
      after_rows: build_rows(after_paths, change_by_path),
      changed_paths: incoming_paths
    }
  end

  private

  attr_reader :dry_run

  def project
    dry_run.project
  end

  def existing_paths
    return [] unless project

    project.documents.includes(:latest_version).filter_map do |document|
      version = document.latest_version
      source_path = version&.source_relative_path.presence || document.slug
      path_label(source_path, document.title)
    end.sort
  end

  def incoming_items
    Array(dry_run.result_json["items"] || dry_run.result_json[:items])
  end

  def incoming_paths
    incoming_items.filter_map do |item|
      source_path = item["source_path"].presence || item[:source_path].presence
      title = item["title"].presence || item.dig("attributes", "title").presence || item.dig(:attributes, :title).presence
      path_label(source_path, title)
    end.sort
  end

  def after_paths
    (existing_paths + incoming_paths).uniq.sort
  end

  def change_by_path
    incoming_items.each_with_object({}) do |item, hash|
      source_path = item["source_path"].presence || item[:source_path].presence
      next if source_path.blank?

      title = item["title"].presence || item.dig("attributes", "title").presence || item.dig(:attributes, :title).presence
      hash[path_label(source_path, title)] = normalize_action(item["action"] || item[:action])
    end
  end

  def normalize_action(action)
    case action.to_s
    when "create"
      :create
    when "update"
      :update
    else
      :change
    end
  end

  def path_label(source_path, title)
    title.present? ? "#{source_path} - #{title}" : source_path.to_s
  end

  def build_rows(paths, changes)
    folder_paths = paths.flat_map { |path| parent_folders(path) }
    all_paths = (folder_paths + paths).uniq.sort

    all_paths.map do |path|
      Row.new(
        path: path,
        label: path.split("/").last,
        depth: [path.count("/"), 8].min,
        change_type: changes[path],
        source: paths.include?(path) ? :document : :folder
      )
    end
  end

  def parent_folders(path)
    parts = path.split("/")
    return [] if parts.size <= 1

    (1...parts.size).map { |index| parts.first(index).join("/") }
  end
end
