import assert from "node:assert/strict"
import test from "node:test"

class FakeClassList {
  constructor() {
    this.values = new Set()
  }

  add(...tokens) {
    tokens.forEach((token) => this.values.add(token))
  }

  contains(token) {
    return this.values.has(token)
  }

  toString() {
    return Array.from(this.values).join(" ")
  }
}

class FakeElement {
  constructor(tagName, ownerDocument) {
    this.tagName = tagName.toUpperCase()
    this.ownerDocument = ownerDocument
    this.attributes = new Map()
    this.children = []
    this.parentNode = null
    this.classList = new FakeClassList()
    this.dataset = {}
    this.eventListeners = new Map()
    this.hidden = false
    this.tabIndex = 0
    this._id = ""
    this._textContent = ""
  }

  get id() {
    return this._id
  }

  set id(value) {
    this._id = value
    if (value) {
      this.attributes.set("id", value)
    } else {
      this.attributes.delete("id")
    }
  }

  get className() {
    return this.classList.toString()
  }

  set className(value) {
    this.classList = new FakeClassList()
    value.split(/\s+/).filter(Boolean).forEach((token) => this.classList.add(token))
  }

  get textContent() {
    return this._textContent
  }

  set textContent(value) {
    this._textContent = value
    if (value === "") {
      this.children.forEach((child) => {
        child.parentNode = null
      })
      this.children = []
    }
  }

  get href() {
    return this.getAttribute("href") || ""
  }

  set href(value) {
    this.setAttribute("href", value)
  }

  get hash() {
    return this.href.startsWith("#") ? this.href : ""
  }

  get nextElementSibling() {
    if (!this.parentNode) {
      return null
    }

    const siblings = this.parentNode.children
    const index = siblings.indexOf(this)
    return index === -1 ? null : siblings[index + 1] || null
  }

  appendChild(child) {
    if (child.parentNode) {
      child.parentNode.children = child.parentNode.children.filter((item) => item !== child)
    }

    child.parentNode = this
    this.children.push(child)
    return child
  }

  insertBefore(child, referenceChild) {
    if (child.parentNode) {
      child.parentNode.children = child.parentNode.children.filter((item) => item !== child)
    }

    const index = this.children.indexOf(referenceChild)
    child.parentNode = this

    if (index === -1) {
      this.children.push(child)
    } else {
      this.children.splice(index, 0, child)
    }

    return child
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value))
  }

  getAttribute(name) {
    return this.attributes.get(name) || null
  }

  addEventListener(type, callback) {
    if (!this.eventListeners.has(type)) {
      this.eventListeners.set(type, [])
    }

    this.eventListeners.get(type).push(callback)
  }

  dispatchEvent(event) {
    const listeners = this.eventListeners.get(event.type) || []
    listeners.forEach((callback) => callback(event))
  }

  focus() {
    this.ownerDocument.activeElement = this
  }

  querySelectorAll(selector) {
    return this.ownerDocument.querySelectorAllFrom(this, selector)
  }
}

class FakeDocument {
  constructor() {
    this.body = new FakeElement("body", this)
    this.eventListeners = new Map()
    this.activeElement = null
  }

  createElement(tagName) {
    return new FakeElement(tagName, this)
  }

  addEventListener(type, callback) {
    if (!this.eventListeners.has(type)) {
      this.eventListeners.set(type, [])
    }

    this.eventListeners.get(type).push(callback)
  }

  dispatchEvent(event) {
    const listeners = this.eventListeners.get(event.type) || []
    listeners.forEach((callback) => callback(event))
  }

  getElementById(id) {
    return this.find((element) => element.id === id)
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null
  }

  querySelectorAll(selector) {
    return this.querySelectorAllFrom(this.body, selector)
  }

  querySelectorAllFrom(root, selector) {
    const matches = []
    this.walk(root, (element) => {
      if (this.matches(element, selector)) {
        matches.push(element)
      }
    })
    return matches
  }

  find(predicate) {
    let found = null
    this.walk(this.body, (element) => {
      if (!found && predicate(element)) {
        found = element
      }
    })
    return found
  }

  walk(root, callback) {
    callback(root)
    root.children.forEach((child) => this.walk(child, callback))
  }

  matches(element, selector) {
    if (selector === '[data-version-tab]') {
      return Boolean(element.dataset.versionTab)
    }

    if (selector === '.document-comment-workspace') {
      return element.classList.contains('document-comment-workspace')
    }

    if (selector === 'nav.markdown-mode-tabs[aria-label="版詳細ナビゲーション"]') {
      return element.tagName === 'NAV' &&
        element.classList.contains('markdown-mode-tabs') &&
        element.getAttribute('aria-label') === '版詳細ナビゲーション'
    }

    return false
  }
}

function buildFixture() {
  const document = new FakeDocument()

  const nav = document.createElement('nav')
  nav.className = 'markdown-mode-tabs'
  nav.setAttribute('aria-label', '版詳細ナビゲーション')

  ;['version-diff', 'side-by-side-file-review', 'version-files'].forEach((id) => {
    const link = document.createElement('a')
    link.href = `#${id}`
    link.textContent = id
    nav.appendChild(link)
  })

  const diffPanel = document.createElement('section')
  diffPanel.id = 'version-diff'

  const sideBySidePanel = document.createElement('section')
  sideBySidePanel.id = 'side-by-side-file-review'

  const info = document.createElement('section')
  info.id = 'current-version-meta'

  const filesHeading = document.createElement('h2')
  filesHeading.id = 'version-files'

  const filesList = document.createElement('ul')

  const comments = document.createElement('section')
  comments.className = 'document-comment-workspace'

  ;[nav, diffPanel, sideBySidePanel, info, filesHeading, filesList, comments].forEach((element) => {
    document.body.appendChild(element)
  })

  return { document, nav }
}

function keydown(key) {
  return {
    type: 'keydown',
    key,
    defaultPrevented: false,
    preventDefault() {
      this.defaultPrevented = true
    }
  }
}

test('document version tabs preserve hash routing, keyboard movement, and ARIA state', async () => {
  const { document, nav } = buildFixture()

  globalThis.document = document
  globalThis.window = {
    location: { hash: '#version-files' },
    eventListeners: new Map(),
    addEventListener(type, callback) {
      this.eventListeners.set(type, callback)
    }
  }
  globalThis.history = {
    pushState(_state, _title, url) {
      globalThis.window.location.hash = url
    }
  }

  await import(new URL('../../app/frontend/controllers/document_version_tabs.js', import.meta.url))
  document.dispatchEvent({ type: 'DOMContentLoaded' })

  const tabs = nav.querySelectorAll('[data-version-tab]')
  assert.equal(tabs.length, 4)
  assert.deepEqual(tabs.map((tab) => tab.getAttribute('aria-controls')), [
    'version-diff',
    'side-by-side-file-review',
    'version-files',
    'version-info'
  ])

  const filesTab = tabs.find((tab) => tab.dataset.versionTab === 'version-files')
  const sideBySideTab = tabs.find((tab) => tab.dataset.versionTab === 'side-by-side-file-review')
  const infoTab = tabs.find((tab) => tab.dataset.versionTab === 'version-info')
  const diffPanel = document.getElementById('version-diff')
  const filesPanel = document.getElementById('version-files')

  assert.equal(filesTab.getAttribute('aria-selected'), 'true')
  assert.equal(filesPanel.hidden, false)
  assert.equal(diffPanel.hidden, true)
  assert.equal(filesPanel.getAttribute('role'), 'tabpanel')
  assert.equal(filesPanel.getAttribute('aria-labelledby'), 'version-tab-version-files')

  const leftEvent = keydown('ArrowLeft')
  filesTab.dispatchEvent(leftEvent)
  assert.equal(leftEvent.defaultPrevented, true)
  assert.equal(globalThis.window.location.hash, '#side-by-side-file-review')
  assert.equal(sideBySideTab.getAttribute('aria-selected'), 'true')
  assert.equal(sideBySideTab.tabIndex, 0)
  assert.equal(filesTab.tabIndex, -1)
  assert.equal(document.activeElement, sideBySideTab)

  const endEvent = keydown('End')
  sideBySideTab.dispatchEvent(endEvent)
  assert.equal(endEvent.defaultPrevented, true)
  assert.equal(globalThis.window.location.hash, '#version-info')
  assert.equal(infoTab.getAttribute('aria-selected'), 'true')

  globalThis.window.location.hash = '#markdown-line-diff'
  globalThis.window.eventListeners.get('hashchange')()
  const diffTab = tabs.find((tab) => tab.dataset.versionTab === 'version-diff')
  assert.equal(diffTab.getAttribute('aria-selected'), 'true')
  assert.equal(diffPanel.hidden, false)
})
