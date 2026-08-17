// tree_view gem v1.0.1 の TypeScript 型宣言（gem 同梱 index.d.ts に基づく）
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

  export const TreeViewControllerIdentifiers: Readonly<{
    state: "tree-view-state"
    client: "tree-view-client"
    selection: "tree-view-selection"
    transfer: "tree-view-transfer"
    remoteState: "tree-view-remote-state"
  }>

  export function registerTreeViewControllers(application: Application): void
}
