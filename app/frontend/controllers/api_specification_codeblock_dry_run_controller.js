import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    url: String,
    user: String
  }

  connect() {
    this.boundDecorateFrame = this.decorateFrame.bind(this)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundDecorateFrame)
      this.decorateFrame()
    }
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundDecorateFrame)
    }
  }

  decorateFrame() {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.httpCodeblocks(frameDocument).forEach((codeblock, index) => {
      const wrapper = this.codeblockWrapper(codeblock)
      if (!wrapper || wrapper.dataset.apiCodeblockDryRunDecorated === "true") return

      wrapper.dataset.apiCodeblockDryRunDecorated = "true"
      const codeblockId = wrapper.id || `admin-api-spec-http-codeblock-${index + 1}`
      wrapper.id = codeblockId
      wrapper.before(this.buildPanel(frameDocument, codeblock, codeblockId))
    })
  }

  frameDocument() {
    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }

  httpCodeblocks(frameDocument) {
    return Array.from(frameDocument.querySelectorAll("pre code.language-http, pre code[class~='language-http']"))
  }

  codeblockWrapper(codeblock) {
    return codeblock.closest("pre")
  }

  buildPanel(frameDocument, codeblock, codeblockId) {
    const panel = frameDocument.createElement("div")
    panel.className = "api-codeblock-dry-run"

    const summary = frameDocument.createElement("p")
    summary.className = "api-codeblock-dry-run__summary"
    summary.textContent = `dry-run validation: ${this.requestTarget(codeblock.textContent)} / ${this.userValue}`

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

  async runDryRun({ codeblock, codeblockId, button, result }) {
    const target = this.requestTarget(codeblock.textContent)
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
      const payload = await response.json()
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

  renderResult(result, payload) {
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

  requestTarget(text) {
    const line = text.split("\n").map((value) => value.trim()).find((value) => value.length > 0) || "未判定"
    const [method, path] = line.split(/\s+/, 3)
    if (!method || !path) return line

    return `${method.toUpperCase()} ${path}`
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
