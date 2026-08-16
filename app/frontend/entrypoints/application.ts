import "./application.css"
import "./admin_layout.css"
import "./user_navbar.css"
import "./home.css"
import "bootstrap-icons/font/bootstrap-icons.css"
import "./nav_current_label.css"
import "./document_version_diff_display_mode.css"
import "./document_version_tabs.css"
import "./document_set_document_filter.css"
import "./bulk_edit_selection.css"
import "./text_preview_cues.css"
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { TomSelectController as RailsFieldsKitTomSelectController } from "rails_fields_kit"
import "tom-select/dist/css/tom-select.css"
import "./tom_select_overrides.css"
import { registerTreeViewControllers } from "tree_view"
import AdminSidebarController from "../controllers/admin_sidebar_controller"
import ApiSpecificationCodeblockDryRunController from "../controllers/api_specification_codeblock_dry_run_controller"
import ArchivePreviewToolsController from "../controllers/archive_preview_tools_controller"
import AutoHeightFrameController from "../controllers/auto_height_frame_controller"
import BulkEditSelectionController from "../controllers/bulk_edit_selection_controller"
import ColumnSettingsDialogController from "../controllers/column_settings_dialog_controller"
import CompanyMasterAdminHandoffController from "../controllers/company_master_admin_handoff_controller"
import CsvPreviewToolsController from "../controllers/csv_preview_tools_controller"
import DocumentFileBrowserController from "../controllers/document_file_browser_controller"
import DocumentFileListSearchController from "../controllers/document_file_list_search_controller"
import DocumentPermissionErrorSurfaceController from "../controllers/document_permission_error_surface_controller"
import DocumentSetDocumentFilterController from "../controllers/document_set_document_filter_controller"
import DocumentVersionTabsController from "../controllers/document_version_tabs"
import DocumentZipSelectionController from "../controllers/document_zip_selection_controller"
import ImagePreviewToolsController from "../controllers/image_preview_tools_controller"
import NavDropdownsController from "../controllers/nav_dropdowns_controller"
import DocumentTreeNavigationController from "../controllers/document_tree_navigation_controller"
import FileDropzoneController from "../controllers/file_dropzone_controller"
import ManualDocumentUploadController from "../controllers/manual_document_upload_controller"
import MarkdownPreviewCodeblockToolsController from "../controllers/markdown_preview_codeblock_tools_controller"
import MarkdownPreviewDocumentSearchController from "../controllers/markdown_preview_document_search_controller"
import MarkdownPreviewTableToolsController from "../controllers/markdown_preview_table_tools_controller"
import PdfPreviewToolsController from "../controllers/pdf_preview_tools_controller"
import PreviewTableResizerController from "../controllers/preview_table_resizer_controller"
import RailsTablePreferencesController from "../controllers/rails_table_preferences_controller"
import RfkDependentFilterController from "../controllers/rfk_dependent_filter_controller"
import SectionNavController from "../controllers/section_nav_controller"
import SidebarController from "../controllers/sidebar_controller"
import SiteViewerIframeHeightController from "../controllers/site_viewer_iframe_height_controller"
import StructuredPreviewToolsController from "../controllers/structured_preview_tools_controller"
import TextPreviewToolsController from "../controllers/text_preview_tools_controller"
import FloatingPanelController from "../controllers/floating_panel_controller"
import ErrorSummaryController from "../controllers/error_summary_controller"
import DirtyFormController from "../controllers/dirty_form_controller"
import SessionTimeoutController from "../controllers/session_timeout_controller"
import HelpTooltipController from "../controllers/help_tooltip_controller"
import ToastController from "../controllers/toast_controller"

const application = Application.start()
window.Stimulus = application
registerTreeViewControllers(application)

// --- コントローラ登録 ---
application.register("admin-sidebar", AdminSidebarController)
application.register("rails-table-preferences", RailsTablePreferencesController)
application.register("api-specification-codeblock-dry-run", ApiSpecificationCodeblockDryRunController)
application.register("archive-preview-tools", ArchivePreviewToolsController)
application.register("auto-height-frame", AutoHeightFrameController)
application.register("bulk-edit-selection", BulkEditSelectionController)
application.register("column-settings-dialog", ColumnSettingsDialogController)
application.register("company-master-admin-handoff", CompanyMasterAdminHandoffController)
application.register("csv-preview-tools", CsvPreviewToolsController)
application.register("document-file-browser", DocumentFileBrowserController)
application.register("document-file-list-search", DocumentFileListSearchController)
application.register("document-permission-error-surface", DocumentPermissionErrorSurfaceController)
application.register("document-set-document-filter", DocumentSetDocumentFilterController)
application.register("document-version-tabs", DocumentVersionTabsController)
application.register("document-zip-selection", DocumentZipSelectionController)
application.register("image-preview-tools", ImagePreviewToolsController)
application.register("nav-dropdowns", NavDropdownsController)
application.register("document-tree-navigation", DocumentTreeNavigationController)
application.register("file-dropzone", FileDropzoneController)
application.register("manual-document-upload", ManualDocumentUploadController)
application.register("markdown-preview-codeblock-tools", MarkdownPreviewCodeblockToolsController)
application.register("markdown-preview-document-search", MarkdownPreviewDocumentSearchController)
application.register("markdown-preview-table-tools", MarkdownPreviewTableToolsController)
application.register("pdf-preview-tools", PdfPreviewToolsController)
application.register("preview-table-resizer", PreviewTableResizerController)
application.register("rfk-dependent-filter", RfkDependentFilterController)
application.register("section-nav", SectionNavController)
application.register("sidebar", SidebarController)
application.register("site-viewer-iframe-height", SiteViewerIframeHeightController)
application.register("structured-preview-tools", StructuredPreviewToolsController)
application.register("text-preview-tools", TextPreviewToolsController)
application.register("floating-panel", FloatingPanelController)
application.register("error-summary", ErrorSummaryController)
application.register("dirty-form", DirtyFormController)
application.register("session-timeout", SessionTimeoutController)
application.register("help-tooltip", HelpTooltipController)
application.register("toast", ToastController)

// --- rfk TomSelect controller 拡張 ---
// overflow 領域の共通動作（候補リストを body へ移す）と free_text 対応
type OverlayTomSelect = {
  isOpen: boolean
  close(): void
}

type ExtendedRfkControllerState = {
  tomSelect?: OverlayTomSelect
}

class ExtendedRfkTomSelectController extends RailsFieldsKitTomSelectController {
  private observedScrollContainers: HTMLElement[] = []
  private readonly closeOverlayDropdownOnScroll = (): void => {
    const tomSelect = (this as unknown as ExtendedRfkControllerState).tomSelect
    if (tomSelect?.isOpen) tomSelect.close()
  }

  connect(): void {
    super.connect()
    this.observedScrollContainers = this.overlayScrollContainers()
    this.observedScrollContainers.forEach((container) => {
      container.addEventListener("scroll", this.closeOverlayDropdownOnScroll, { passive: true })
    })
  }

  disconnect(): void {
    this.observedScrollContainers.forEach((container) => {
      container.removeEventListener("scroll", this.closeOverlayDropdownOnScroll)
    })
    this.observedScrollContainers = []
    super.disconnect()
  }

  options(): Record<string, unknown> {
    const opts: Record<string, unknown> = super.options()
    // free_text モード: Enter で「追加:xxx」を優先し、フォーカス移動時にも値を確定する
    if (this.freeTextValue) {
      opts.addPrecedence = true
      opts.createOnBlur = true
    }
    // multi モード: 候補選択後に入力テキストをクリアする
    if ((this.element as HTMLSelectElement).multiple) {
      opts.clearAfterSelect = true
    }

    const overlayClass = this.overlayDropdownClass()
    if (overlayClass) {
      // table/modalのoverflow境界を越えるため候補リストだけbodyへ移す。
      // 元のinput/selectはフォーム内に残るため送信値には影響しない。
      if (!opts.dropdownParent) opts.dropdownParent = "body"
      const dropdownClass = typeof opts.dropdownClass === "string" ? opts.dropdownClass : "ts-dropdown"
      opts.dropdownClass = `${dropdownClass} rfk-overlay-dropdown ${overlayClass}`
    }
    return opts
  }

  private overlayDropdownClass(): string | null {
    const element = this.element as HTMLElement
    if (element.closest(".modal")) return "rfk-modal-dropdown"
    if (element.closest(".table-responsive")) return "rfk-table-dropdown"
    return null
  }

  private overlayScrollContainers(): HTMLElement[] {
    const element = this.element as HTMLElement
    const containers = [
      element.closest<HTMLElement>(".table-responsive"),
      element.closest<HTMLElement>(".modal-body"),
    ].filter((container): container is HTMLElement => container !== null)
    return Array.from(new Set(containers))
  }
}
application.register("rails-fields-kit--tom-select", ExtendedRfkTomSelectController)

export { application }
