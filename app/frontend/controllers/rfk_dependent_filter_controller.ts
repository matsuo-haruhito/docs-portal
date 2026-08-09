import { Controller } from "@hotwired/stimulus"

type TomSelectInstance = {
  clear: (silent?: boolean) => void
  clearOptions: () => void
}

type RfkSelectElement = HTMLSelectElement & {
  tomselect?: TomSelectInstance
}

const RFK_URL_ATTRIBUTE = "data-rails-fields-kit--tom-select-url-value"

export default class extends Controller {
  static targets = ["repository", "branch", "path"]
  static values = {
    branchUrl: String,
    pathUrl: String
  }

  declare readonly repositoryTarget: RfkSelectElement
  declare readonly branchTarget: RfkSelectElement
  declare readonly pathTarget: RfkSelectElement
  declare readonly branchUrlValue: string
  declare readonly pathUrlValue: string

  connect(): void {
    this.refreshBranchUrl()
    this.refreshPathUrl()
  }

  repositoryChanged(): void {
    this.clearField(this.branchTarget)
    this.clearField(this.pathTarget)
    this.refreshBranchUrl()
    this.refreshPathUrl()
  }

  branchChanged(): void {
    this.clearField(this.pathTarget)
    this.refreshPathUrl()
  }

  private refreshBranchUrl(): void {
    this.updateFieldUrl(this.branchTarget, this.branchUrlValue, {
      repository: this.repositoryTarget.value
    })
  }

  private refreshPathUrl(): void {
    this.updateFieldUrl(this.pathTarget, this.pathUrlValue, {
      repository: this.repositoryTarget.value,
      branch: this.branchTarget.value
    })
  }

  private updateFieldUrl(field: RfkSelectElement, baseUrl: string, params: Record<string, string>): void {
    const url = new URL(baseUrl, window.location.origin)

    Object.entries(params).forEach(([key, value]) => {
      const normalizedValue = value.trim()
      if (normalizedValue) {
        url.searchParams.set(key, normalizedValue)
      } else {
        url.searchParams.delete(key)
      }
    })

    field.setAttribute(RFK_URL_ATTRIBUTE, `${url.pathname}${url.search}`)
  }

  private clearField(field: RfkSelectElement): void {
    const tomSelect = field.tomselect
    if (tomSelect) {
      tomSelect.clear(true)
      tomSelect.clearOptions()
    }

    field.value = ""
  }
}
