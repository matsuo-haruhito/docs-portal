import TomSelect from "tom-select"

function splitList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
}

function booleanValue(value) {
  return value === true || value === "true" || value === "1"
}

function numberValue(value, fallback) {
  const number = Number(value)
  return Number.isFinite(number) ? number : fallback
}

function buildCreateOption(input) {
  const value = input.trim()
  if (value === "") return false

  return {
    value,
    label: value
  }
}

function buildRemoteLoader(element) {
  const url = element.dataset.tomSelectUrl
  if (!url) return undefined

  const minLength = numberValue(element.dataset.tomSelectMinLength, 1)
  const searchFields = splitList(element.dataset.tomSelectSearchFields)
  const valueMode = element.dataset.tomSelectValueMode || "text"

  return (query, callback) => {
    const q = query.trim()
    if (q.length < minLength) {
      callback()
      return
    }

    const params = new URLSearchParams()
    params.set("q", q)
    params.set("value_mode", valueMode)
    if (searchFields.length > 0) params.set("fields", searchFields.join(","))

    fetch(`${url}?${params.toString()}`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error("Tom Select options request failed")
        return response.json()
      })
      .then((json) => callback(json))
      .catch(() => callback())
  }
}

function validateForceSelect(tomSelect) {
  const element = tomSelect.input
  if (!booleanValue(element.dataset.tomSelectForceSelect)) return

  const rawValue = tomSelect.getValue()
  const values = Array.isArray(rawValue) ? rawValue : [rawValue]
  const invalid = values.some((value) => value && !tomSelect.options[value])

  element.setCustomValidity(invalid ? "候補から選択してください" : "")
}

export function setupTomSelectFields(root = document) {
  root.querySelectorAll("[data-tom-select='true']").forEach((element) => {
    if (element.tomselect) return

    const multiple = booleanValue(element.dataset.tomSelectMultiple)
    const create = booleanValue(element.dataset.tomSelectCreate)
    const forceSelect = booleanValue(element.dataset.tomSelectForceSelect)
    const valueMode = element.dataset.tomSelectValueMode || "text"
    const valueField = valueMode === "id" ? "id" : "value"
    const searchFields = splitList(element.dataset.tomSelectSearchFields)

    const tomSelect = new TomSelect(element, {
      valueField,
      labelField: "label",
      searchField: searchFields.length > 0 ? searchFields : ["label"],
      maxItems: multiple ? null : 1,
      maxOptions: numberValue(element.dataset.tomSelectMaxOptions, 20),
      persist: false,
      preload: false,
      loadThrottle: numberValue(element.dataset.tomSelectLoadThrottle, 250),
      create: create && !forceSelect ? buildCreateOption : false,
      plugins: multiple ? ["remove_button"] : [],
      load: buildRemoteLoader(element),
      onBlur() {
        validateForceSelect(tomSelect)
      },
      onChange() {
        validateForceSelect(tomSelect)
      }
    })
  })
}
