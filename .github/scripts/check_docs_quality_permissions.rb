#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

workflow_path = File.expand_path("../workflows/docs-quality.yml", __dir__)
workflow = YAML.safe_load_file(workflow_path, aliases: true)
permissions = workflow.fetch("permissions", {})

expected_permissions = { "contents" => "read" }

unless permissions == expected_permissions
  abort <<~MESSAGE
    docs-quality workflow must keep the minimum GITHUB_TOKEN permissions.
    Expected: #{expected_permissions.inspect}
    Actual:   #{permissions.inspect}
  MESSAGE
end

puts "docs-quality GITHUB_TOKEN permissions are limited to contents: read"
