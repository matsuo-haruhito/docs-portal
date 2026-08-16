// rails_table_preferences gem の TypeScript 型宣言
declare module "rails_table_preferences" {
  import { Controller } from "@hotwired/stimulus"

  export class RailsTablePreferencesController extends Controller {
    static targets: string[]
    static values: Record<string, unknown>

    busy: boolean
    presets: Array<Record<string, unknown>>
    currentPreferenceEditable: boolean
    defaultSettings: Record<string, unknown>
    settingsValue: Record<string, unknown>
    tableKeyValue: string
    nameValue: string
    urlValue: string
    collectionUrlValue: string

    hasPresetSelectTarget: boolean
    hasPresetNameTarget: boolean
    hasDefaultPresetTarget: boolean
    hasEditorRowsTarget: boolean
    hasStatusTarget: boolean
    hasReadOnlyHintTarget: boolean
    hasDirtyStateTarget: boolean

    presetSelectTarget: HTMLSelectElement
    presetNameTarget: HTMLInputElement
    defaultPresetTarget: HTMLInputElement
    editorRowsTarget: HTMLElement
    statusTarget: HTMLElement

    connect(): void
    disconnect(): void
    apply(): void
    renderEditor(): void
    applyFromEditor(event?: Event): void
    save(event?: Event): Promise<void>
    createPresetFromEditor(event?: Event): Promise<void>
    resetEditor(event?: Event): void
    refreshPresetOptionsOnConnect(): Promise<void>
    refreshPresetOptions(): Promise<void>
    renderPresetOptions(): void
    selectPreset(event?: Event): Promise<unknown>
    setBusyState(busy: boolean): void
    setEditorRowsBusyState(busy: boolean): void
    setTableInteractionBusyState(busy: boolean): void
    setStatus(message: string, variant?: string): void
    closeFilterPanel(): void
    shouldIgnoreHeaderAction(target: Element): boolean
    sortFor(key: string): { key: string; direction: string } | undefined
    toggleSortFromHeader(event: Event, cell: HTMLElement, column: { key: string; sortable?: boolean }): void
    stopColumnResize(): void
    autoFitColumnFromHandle(event: Event): void
    endTableColumnDrag(event: DragEvent): void
    syncEditorWidthInputs(): void
    syncPresetEditingState(): void
    syncPresetSearchState(opts: { query: string; visibleCount: number; enabled: boolean }): void
    syncDeletePresetButtonContext(): void
    withBusyStatus(callback: () => Promise<unknown>, labels?: Record<string, string>): Promise<unknown>
    buildDefaultSettings(): Record<string, unknown>
    mergeSettings(defaults: Record<string, unknown>, saved: Record<string, unknown>): Record<string, unknown>

    get currentPresetName(): string
    get presetSearchQuery(): string
    get presetSearchControl(): HTMLElement | null
    get editorRows(): HTMLElement[]
  }

  export default RailsTablePreferencesController
}
