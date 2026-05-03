require "cgi"

module SeedSupport
  class DocusaurusRouteMap
    DOC_ID_PATTERN = /docs-doc-id-([^"\s]+)/

    def initialize(site_root_absolute_path:, site_build_path:)
      @site_root_absolute_path = Pathname(site_root_absolute_path)
      @site_build_path = site_build_path
    end

    def build
      Dir.glob(@site_root_absolute_path.join("**/index.html").to_s).each_with_object({}) do |html_path, result|
        route_path = route_path_for(html_path)
        doc_ids = File.read(html_path).scan(DOC_ID_PATTERN).flatten
        next if doc_ids.empty?

        doc_ids.each do |doc_id|
          decoded_doc_id = CGI.unescapeHTML(doc_id)
          result[decoded_doc_id] ||= route_path
          result[decoded_doc_id.split("/").last] ||= route_path
        end
      end
    end

    private

    def route_path_for(html_path)
      relative_path = Pathname(html_path).relative_path_from(@site_root_absolute_path).to_s
      route_path = relative_path.delete_suffix("/index.html")
      route_path.presence || @site_build_path
    end
  end
end
