// rails_fields_kit gem の TypeScript 型宣言
declare module "rails_fields_kit" {
  import { Controller } from "@hotwired/stimulus"

  export class TomSelectController extends Controller {
    static targets: string[]
    static values: Record<string, unknown>
    queryParamsValue: Record<string, string>
    freeTextValue: boolean
    tomSelect: unknown
    preloadValue: boolean
    connect(): void
    disconnect(): void
    options(): Record<string, unknown>
  }
}
