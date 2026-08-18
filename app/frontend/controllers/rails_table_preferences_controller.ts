import { RailsTablePreferencesController as BaseController } from "rails_table_preferences"

type ColumnSetting = {
  key: string
  order?: number
  width?: number
  [key: string]: unknown
}

type TableSettings = {
  columns?: ColumnSetting[]
  [key: string]: unknown
}

type RtpController = BaseController & {
  settingsValue: TableSettings
  renderEditor: () => void
}

export default class extends BaseController {
  private dialogElement: HTMLDialogElement | null = null
  private readonly syncFromTableOnOpen = () => this.syncFromPairedTable()

  connect(): void {
    super.connect()

    if (this.hasPresetSelectTarget) {
      this.dialogElement = this.element.closest("dialog.column-settings__dialog")
      this.dialogElement?.addEventListener("column-settings-dialog:opened", this.syncFromTableOnOpen)
      this.addInputPlaceholders()
    }
  }

  disconnect(): void {
    this.dialogElement?.removeEventListener("column-settings-dialog:opened", this.syncFromTableOnOpen)
    this.dialogElement = null
    super.disconnect()
  }

  renderEditor(): void {
    super.renderEditor()
    this.addInputPlaceholders()
  }

  stopColumnResize(): void {
    super.stopColumnResize()
    this.syncToPairedEditor()
  }

  autoFitColumnFromHandle(event: Event): void {
    super.autoFitColumnFromHandle(event)
    this.syncToPairedEditor()
  }

  endTableColumnDrag(event: DragEvent): void {
    super.endTableColumnDrag(event)
    this.syncToPairedEditor()
  }

  private addInputPlaceholders(): void {
    const placeholders: Record<string, string> = {
      order: "順",
      width: "幅",
      truncate: "省略"
    }

    this.element.querySelectorAll<HTMLInputElement>('.rails-table-preferences-editor__row input[type="number"]').forEach((input) => {
      const field = input.dataset.field
      if (field && placeholders[field]) input.placeholder ||= placeholders[field]
    })
  }

  private syncFromPairedTable(): void {
    const tableController = this.pairedController("table")
    if (!tableController) return

    this.mergeColumnLayout(tableController.settingsValue)
  }

  private syncToPairedEditor(): void {
    const editorController = this.pairedController(".rails-table-preferences-editor")
    if (!editorController) return

    editorController.mergeColumnLayout(this.settingsValue as TableSettings)
  }

  private mergeColumnLayout(sourceSettings: TableSettings): void {
    const sourceColumns = new Map((sourceSettings.columns || []).map((column) => [column.key, column]))
    const currentSettings = (this.settingsValue || {}) as TableSettings
    const currentColumns = currentSettings.columns || []
    const columns = currentColumns.map((column: ColumnSetting) => {
      const source = sourceColumns.get(column.key)
      if (!source) return column

      return {
        ...column,
        order: source.order ?? column.order,
        width: source.width ?? column.width
      }
    }).sort((left: ColumnSetting, right: ColumnSetting) => (left.order ?? Number.MAX_SAFE_INTEGER) - (right.order ?? Number.MAX_SAFE_INTEGER))

    this.settingsValue = { ...currentSettings, columns }
    if (this.hasEditorRowsTarget) this.renderEditor()
  }

  private pairedController(selector: "table" | ".rails-table-preferences-editor"): (RtpController & { mergeColumnLayout: (settings: TableSettings) => void }) | null {
    const escapedTableKey = CSS.escape(String(this.tableKeyValue))
    const element = document.querySelector<HTMLElement>(
      `${selector}[data-controller~="rails-table-preferences"][data-rails-table-preferences-table-key-value="${escapedTableKey}"]`
    )
    if (!element || element === this.element) return null

    return this.application.getControllerForElementAndIdentifier(
      element,
      "rails-table-preferences"
    ) as (RtpController & { mergeColumnLayout: (settings: TableSettings) => void }) | null
  }
}
