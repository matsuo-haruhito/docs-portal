import { execSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"

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
      rails_table_preferences: gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/index.js"),
      "rails_table_preferences/controller": gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/controller.js"),
      rails_fields_kit: gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/index.js"),
      "rails_fields_kit/tom_select_controller": gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/tom_select_controller.js"),
    },
  },
})