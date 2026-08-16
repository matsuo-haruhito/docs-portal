import { Controller } from "@hotwired/stimulus"

interface DryRunPayload {
  status?: string
  message?: string
  details?: string[]
}

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    url: String,
    user: String
  }

  declare readonly hasFrameTarget: boolean
  declare readonly frameTarget: HTMLIFrameElement
  declare urlValue: string
  declare userValue: string

  private boundDecorateFrame!: () => void

  connect(): void {
    this.boundDecorateFrame = this.decorateFrame.bind(this)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundDecorateFrame)
      this.decorateFrame()
    }
  }

  disconnect(): void {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundDecorateFrame)
    }
  }

  decorateFrame(): void {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.ensureFrameStyles(frameDocument)

    this.httpCodeblocks(frameDocument).forEach((codeblock, index) => {
      const wrapper = this.codeblockWrapper(codeblock)
      if (!wrapper || (wrapper as HTMLElement).dataset.apiCodeblockDryRunDecorated === "true") return

      ;(wrapper as HTMLElement).dataset.apiCodeblockDryRunDecorated = "true"
      const codeblockId = wrapper.id || `admin-api-spec-http-codeblock-${index + 1}`
      wrapper.id = codeblockId
      wrapper.before(this.buildPanel(frameDocument, codeblock, codeblockId))
    })
  }

  private frameDocument(): Document | null {
    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }

  private ensureFrameStyles(frameDocument: Document): void {
    if (frameDocument.getElementById("api-codeblock-dry-run-style")) return

    const style = frameDocument.createElement("style")
    style.id = "api-codeblock-dry-run-style"
    style.textContent = `
      .api-codeblock-dry-run {
        display: flex;
        flex-wrap: wrap;
        gap: 8px 12px;
        align-items: center;
        margin: 0 0 8px;
        padding: 10px 12px;
        border: 1px solid #bfdbfe;
        border-radius: 8px;
        background: #eff6ff;
        color: #172033;
      }
      .api-codeblock-dry-run__summary {
        flex: 1 1 260px;
        margin: 0;
        color: #334155;
        font-size: 0.92rem;
      }
      .api-codeblock-dry-run__button {
        flex: 0 0 auto;
        border: 1px solid #0f62fe;
        border-radius: 999px;
        background: #0f62fe;
        color: #fff;
        padding: 6px 12px;
        cursor: pointer;
      }
      .api-codeblock-dry-run__button:disabled {
        cursor: wait;
        opacity: 0.7;
      }
      .api-codeblock-dry-run__result {
        flex: 1 1 100%;
        padding: 8px 10px;
        border-radius: 8px;
        background: #fff;
        border: 1px solid #cbd5e1;
      }
      .api-codeblock-dry-run__result p {
        margin: 0;
      }
      .api-codeblock-dry-run__result ul {
        margin: 6px 0 0;
        padding-left: 1.2rem;
      }
      .api-codeblock-dry-run__result.is-ok {
        border-color: #86efac;
        background: #f0fdf4;
      }
      .api-codeblock-dry-run__result.is-running {
        border-color: #bfdbfe;
        background: #eff6ff;
      }
      .api-codeblock-dry-run__result.is-error {
        border-color: #fecaca;
        background: #fef2f2;
      }
    `
    frameDocument.head?.appendChild(style)
  }

  private httpCodeblocks(frameDocument: Document): Element[] {
    return Array.from(frameDocument.querySelectorAll("pre code.language-http, pre code[class~='language-http']"))
  }

  private codeblockWrapper(codeblock: Element): HTMLElement | null {
    return codeblock.closest("pre")
  }

  private buildPanel(frameDocument: Document, codeblock: Element, codeblockId: string): HTMLElement {
    const panel = frameDocument.createElement("div")
    panel.className = "api-codeblock-dry-run"

    const summary = frameDocument.createElement("p")
    summary.className = "api-codeblock-dry-run__summary"
    summary.textContent = `dry-run validation: ${this.requestTarget(codeblock.textContent || "")} / ${this.userValue}`

    const button = frameDocument.createElement("button")
    button.type = "button"
    button.className = "api-codeblock-dry-run__button"
    button.textContent = "Dry-run validation"

    const result = frameDocument.createElement("div")
    result.className = "api-codeblock-dry-run__result"
    result.hidden = true

    button.addEventListener("click", () => {
      this.runDryRun({ codeblock, codeblockId, button, result })
    })

    panel.append(summary, button, result)
    return panel
  }

  private async runDryRun({ codeblock, codeblockId, button, result }: { codeblock: Element; codeblockId: string; button: HTMLButtonElement; result: HTMLElement }): Promise<void> {
    const target = this.requestTarget(codeblock.textContent || "")
    const confirmed = window.confirm(`dry-run validation を実行します。\n対象 API: ${target}\n実行ユーザー: ${this.userValue}\napply / import / 外部送信は行いません。`)
    if (!confirmed) return

    button.disabled = true
    this.renderResult(result, { status: "running", message: "dry-run validation を実行中です。", details: [] })

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({
          codeblock: codeblock.textContent,
          codeblock_id: codeblockId
        })
      })
      const payload: DryRunPayload = await response.json()
      this.renderResult(result, payload)
    } catch (_error) {
      this.renderResult(result, {
        status: "error",
        message: "dry-run validation の結果を取得できませんでした。viewer 表示は変更していません。",
        details: []
      })
    } finally {
      button.disabled = false
    }
  }

  private renderResult(result: HTMLElement, payload: DryRunPayload): void {
    result.hidden = false
    result.className = `api-codeblock-dry-run__result is-${payload.status || "error"}`
    result.replaceChildren()

    const message = result.ownerDocument.createElement("p")
    message.textContent = payload.message || "dry-run validation の結果がありません。"
    result.appendChild(message)

    if (Array.isArray(payload.details) && payload.details.length > 0) {
      const list = result.ownerDocument.createElement("ul")
      payload.details.forEach((detail) => {
        const item = result.ownerDocument.createElement("li")
        item.textContent = detail
        list.appendChild(item)
      })
      result.appendChild(list)
    }
  }

  private requestTarget(text: string): string {
    const line = text.split("\n").map((value) => value.trim()).find((value) => value.length > 0) || "未判定"
    const [method, path] = line.split(/\s+/, 3)
    if (!method || !path) return line

    return `${method.toUpperCase()} ${path}`
  }

  private csrfToken(): string {
    return document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content || ""
  }
}
