// tree_view gem v1.0.1 同梱の index.d.ts に基づく型宣言
// gem source: app/javascript/tree_view/index.d.ts
declare module "tree_view" {
  import { Controller } from "@hotwired/stimulus"
  import type { Application } from "@hotwired/stimulus"

  export class TreeViewClientController extends Controller {}
  export class TreeViewRemoteStateController extends Controller {}
  export class TreeViewSelectionController extends Controller {}
  export class TreeViewStateController extends Controller {}
  export class TreeViewTransferController extends Controller {}

  export const TreeViewEventNames: Readonly<{
    state: Readonly<{ stateChanged: "tree-view-state:state-changed" }>
    selection: Readonly<{
      change: "tree-view-selection:change"
      selected: "tree-view-selection:selected"
      limitExceeded: "tree-view-selection:limit-exceeded"
      invalidPayload: "tree-view-selection:invalid-payload"
    }>
    remoteState: Readonly<{
      change: "tree-view-remote-state:change"
      retry: "tree-view-remote-state:retry"
    }>
    hostLifecycle: Readonly<{
      loading: "tree-view:loading"
      loaded: "tree-view:loaded"
      error: "tree-view:error"
      retry: "tree-view:retry"
    }>
    transfer: Readonly<{
      dragStart: "tree-view-transfer:drag-start"
      dragOver: "tree-view-transfer:drag-over"
      drop: "tree-view-transfer:drop"
      invalidPayload: "tree-view-transfer:invalid-payload"
      invalidTransfer: "tree-view-transfer:invalid-transfer"
    }>
  }>

  export const TreeViewEventDetailKeys: Readonly<{
    state: Readonly<{
      stateChanged: readonly ["viewKey", "expandedKeys", "reason"]
    }>
    selection: Readonly<{
      change: readonly ["selectedCount", "selectedValues", "selectedPayloads", "sourceCheckbox", "attemptedChecked"]
      selected: readonly ["payloads"]
      limitExceeded: readonly ["maxCount", "attemptedCount", "attemptedChecked", "checkbox"]
      invalidPayload: readonly ["value", "checkbox"]
    }>
    remoteState: Readonly<{
      change: readonly ["row", "state", "childrenUrl", "nodeKey"]
      retry: readonly ["row", "childrenUrl", "nodeKey"]
    }>
    transfer: Readonly<{
      dragStart: readonly ["sourcePayload", "sourceRow"]
      dragOver: readonly ["targetPayload", "targetRow", "position"]
      drop: readonly ["sourcePayload", "targetPayload", "position", "targetRow"]
      invalidPayload: readonly ["value", "row"]
      invalidTransfer: readonly ["value"]
    }>
  }>

  export const TreeViewStateChangeReasons: Readonly<{
    connect: "connect"
    refresh: "refresh"
    expanded: "expanded"
    collapsed: "collapsed"
  }>

  export const TreeViewRemoteStateValues: Readonly<{
    loading: "loading"
    loaded: "loaded"
    error: "error"
  }>

  export const TreeViewRemoteStateDataHooks: Readonly<{
    lazyAttribute: "data-tree-lazy"
    childrenUrlAttribute: "data-tree-children-url"
    loadedAttribute: "data-tree-loaded"
    remoteStateAttribute: "data-tree-remote-state"
  }>

  export const TreeViewToolbarDataHooks: Readonly<{
    toolbarAttribute: "data-tree-view-toolbar"
    actionAttribute: "data-tree-view-toolbar-action"
    disabledAttribute: "data-tree-view-toolbar-disabled"
  }>

  export const TreeViewTransferDropPositions: Readonly<{
    before: "before"
    inside: "inside"
    after: "after"
  }>

  export const TreeViewTransferDataAttributes: Readonly<{
    payload: "data-tree-transfer-payload"
    disabled: "data-tree-transfer-disabled"
  }>

  export const TreeViewTransferDataMimeTypes: Readonly<{
    applicationJson: "application/json"
    textPlain: "text/plain"
  }>

  export const TreeViewControllerIdentifiers: Readonly<{
    state: "tree-view-state"
    client: "tree-view-client"
    selection: "tree-view-selection"
    transfer: "tree-view-transfer"
    remoteState: "tree-view-remote-state"
  }>

  export const TreeViewControllerEntries: readonly [
    Readonly<{
      key: "state"
      identifier: "tree-view-state"
      controller: typeof TreeViewStateController
    }>,
    Readonly<{
      key: "client"
      identifier: "tree-view-client"
      controller: typeof TreeViewClientController
    }>,
    Readonly<{
      key: "selection"
      identifier: "tree-view-selection"
      controller: typeof TreeViewSelectionController
    }>,
    Readonly<{
      key: "transfer"
      identifier: "tree-view-transfer"
      controller: typeof TreeViewTransferController
    }>,
    Readonly<{
      key: "remoteState"
      identifier: "tree-view-remote-state"
      controller: typeof TreeViewRemoteStateController
    }>
  ]

  export const TreeViewIntegrationHooks: Readonly<{
    state: Readonly<{
      viewKeyValue: "data-tree-view-state-view-key-value"
      nodeKey: "data-tree-view-state-node-key"
    }>
    remoteState: Readonly<{
      childrenUrl: "data-tree-children-url"
    }>
    transfer: Readonly<{
      payload: "data-tree-transfer-payload"
    }>
  }>

  export const TreeViewSelectionDataHooks: Readonly<{
    hiddenInputNameValue: "data-tree-view-selection-hidden-input-name-value"
    maxCountValue: "data-tree-view-selection-max-count-value"
    cascadeValue: "data-tree-view-selection-cascade-value"
    indeterminateValue: "data-tree-view-selection-indeterminate-value"
  }>

  export const TreeViewSelectionCheckboxHooks: Readonly<{
    checkboxClass: "tree-selection-checkbox"
    disabledReasonAttribute: "data-tree-selection-disabled-reason"
  }>

  export const TreeViewEmptyStateHooks: Readonly<{
    wrapperAttribute: "data-tree-view-empty-state"
    contentClass: "tree-view-empty-row__content"
    messageClass: "tree-view-empty-row__message"
  }>

  export function registerTreeViewControllers(application: Application): void
}
