import "./application.css"
import "./bootstrap_overrides.css"
import "./nav_current_label.css"
import "./document_version_diff_display_mode.css"
import "./document_version_tabs.css"
import "./document_set_document_filter.css"
import "./bulk_edit_selection.css"
import "./text_preview_cues.css"
import "./api_specification_codeblock_dry_run.css"
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { RailsTablePreferencesController } from "rails_table_preferences"
import { TomSelectController } from "rails_fields_kit"
import "tom-select/dist/css/tom-select.css"
import ApiSpecificationCodeblockDryRunController from "../controllers/api_specification_codeblock_dry_run_controller"
import ArchivePreviewToolsController from "../controllers/archive_preview_tools_controller"
import AutoHeightFrameController from "../controllers/auto_height_frame_controller"
import BulkEditSelectionController from "../controllers/bulk_edit_selection_controller"
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
import SidebarController from "../controllers/sidebar_controller"
import SiteViewerIframeHeightController from "../controllers/site_viewer_iframe_height_controller"
import StructuredPreviewToolsController from "../controllers/structured_preview_tools_controller"
import TextPreviewToolsController from "../controllers/text_preview_tools_controller"

const application = Application.start()
application.register("rails-table-preferences", RailsTablePreferencesController)
application.register("rails-fields-kit--tom-select", TomSelectController)
application.register("api-specification-codeblock-dry-run", ApiSpecificationCodeblockDryRunController)
application.register("archive-preview-tools", ArchivePreviewToolsController)
application.register("auto-height-frame", AutoHeightFrameController)
application.register("bulk-edit-selection", BulkEditSelectionController)
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
application.register("sidebar", SidebarController)
application.register("site-viewer-iframe-height", SiteViewerIframeHeightController)
application.register("structured-preview-tools", StructuredPreviewToolsController)
application.register("text-preview-tools", TextPreviewToolsController)
