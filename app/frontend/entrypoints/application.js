import "./application.css"
import "./document_version_diff_display_mode.css"
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { RailsTablePreferencesController } from "rails_table_preferences"
import { TomSelectController } from "rails_fields_kit"
import "tom-select/dist/css/tom-select.css"
import DocumentFileBrowserController from "../controllers/document_file_browser_controller"
import DocumentZipSelectionController from "../controllers/document_zip_selection_controller"
import NavDropdownsController from "../controllers/nav_dropdowns_controller"
import DocumentTreeNavigationController from "../controllers/document_tree_navigation_controller"
import FileDropzoneController from "../controllers/file_dropzone_controller"
import ManualDocumentUploadController from "../controllers/manual_document_upload_controller"
import PreviewTableResizerController from "../controllers/preview_table_resizer_controller"
import PreviewToolsController from "../controllers/preview_tools_controller"
import SidebarController from "../controllers/sidebar_controller"

const application = Application.start()
application.register("rails-table-preferences", RailsTablePreferencesController)
application.register("rails-fields-kit--tom-select", TomSelectController)
application.register("document-file-browser", DocumentFileBrowserController)
application.register("document-zip-selection", DocumentZipSelectionController)
application.register("nav-dropdowns", NavDropdownsController)
application.register("document-tree-navigation", DocumentTreeNavigationController)
application.register("file-dropzone", FileDropzoneController)
application.register("manual-document-upload", ManualDocumentUploadController)
application.register("preview-table-resizer", PreviewTableResizerController)
application.register("preview-tools", PreviewToolsController)
application.register("sidebar", SidebarController)
