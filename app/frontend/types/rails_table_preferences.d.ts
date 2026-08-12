declare module "rails_table_preferences" {
  import { Controller } from "@hotwired/stimulus"

  export type RailsTablePreferenceColumn = {
    key: string
    order?: number
    width?: number
    [key: string]: unknown
  }

  export type RailsTablePreferenceSettings = {
    columns?: RailsTablePreferenceColumn[]
    [key: string]: unknown
  }

  export class RailsTablePreferencesController extends Controller<HTMLElement> {
    hasPresetSelectTarget: boolean
    presetSelectTarget: HTMLSelectElement
    hasEditorRowsTarget: boolean
    tableKeyValue: string
    settingsValue: RailsTablePreferenceSettings
    connect(): void
    disconnect(): void
    refreshPresetOptionsOnConnect(): Promise<void>
    renderEditor(): void
    stopColumnResize(): void
    autoFitColumnFromHandle(event: Event): void
    endTableColumnDrag(event: DragEvent): void
  }
}
