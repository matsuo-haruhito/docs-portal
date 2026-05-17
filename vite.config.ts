import { execSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"

function projectPath(path: string) {
  return fileURLToPath(new URL(path, import.meta.url))
}

function gemPath(name: string) {
  return execSync(`bundle show ${name}`, { encoding: "utf-8" }).trim()
}

function gemJavaScriptPath(name: string, entrypoint: string) {
  return fileURLToPath(new URL(`app/javascript/${entrypoint}`, `file://${gemPath(name)}/`))
}

export default defineConfig({
  plugins: [
    RubyPlugin(),
  ],
  resolve: {
    alias: {
      "@hotwired/stimulus": projectPath("node_modules/@hotwired/stimulus/dist/stimulus.js"),
      "@hotwired/turbo-rails": projectPath("node_modules/@hotwired/turbo-rails/app/javascript/turbo/index.js"),
      "tom-select": projectPath("node_modules/tom-select/dist/js/tom-select.complete.js"),
      rails_table_preferences: gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/index.js"),
      "rails_table_preferences/controller": gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/controller.js"),
      rails_fields_kit: gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/index.js"),
      "rails_fields_kit/tom_select_controller": gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/tom_select_controller.js"),
    },
  },
})