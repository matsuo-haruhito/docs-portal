import type { Application } from "@hotwired/stimulus"

declare global {
  interface Window {
    Stimulus: Application
    Turbo?: {
      visit(url: string, options?: { action?: string }): void
    }
  }
}

// Vite がインポートする CSS モジュールの型宣言
declare module "*.css" {
  const content: string
  export default content
}

// Side-effect CSS imports（Vite で処理される）
declare module "tom-select/dist/css/tom-select.css" {}
declare module "tom-select/dist/css/*.css" {}
declare module "bootstrap-icons/font/bootstrap-icons.css" {}

// @hotwired/turbo-rails の型宣言
declare module "@hotwired/turbo-rails" {
  export {}
}

export {}
