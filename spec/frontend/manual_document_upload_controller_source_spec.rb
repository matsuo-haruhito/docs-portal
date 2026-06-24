require "spec_helper"

RSpec.describe "manual-document-upload controller source" do
  let(:source_path) { File.expand_path("../../app/frontend/controllers/manual_document_upload_controller.js", __dir__) }
  let(:source) { File.read(source_path) }

  it "keeps window drag listeners inside the Stimulus lifecycle" do
    expect(source).to include("window.addEventListener(\"dragenter\", this.boundWindowDragEnter)")
    expect(source).to include("window.addEventListener(\"dragover\", this.boundWindowDragOver)")
    expect(source).to include("window.addEventListener(\"drop\", this.boundWindowDragEnd)")
    expect(source).to include("window.addEventListener(\"dragend\", this.boundWindowDragEnd)")

    expect(source).to include("window.removeEventListener(\"dragenter\", this.boundWindowDragEnter)")
    expect(source).to include("window.removeEventListener(\"dragover\", this.boundWindowDragOver)")
    expect(source).to include("window.removeEventListener(\"drop\", this.boundWindowDragEnd)")
    expect(source).to include("window.removeEventListener(\"dragend\", this.boundWindowDragEnd)")
  end

  it "keeps iframe document drag listeners attachable and removable" do
    expect(source).to include("this.frameTarget.addEventListener(\"load\", this.boundHandleFrameLoad)")
    expect(source).to include("this.frameTarget.removeEventListener(\"load\", this.boundHandleFrameLoad)")
    expect(source).to include("this.disconnectFrameDocument()\n\n    const frameDocument = this.frameDocument()")
    expect(source).to include("if (!frameDocument) return")

    expect(source).to include("frameDocument.addEventListener(\"dragenter\", this.boundFrameDragEnter)")
    expect(source).to include("frameDocument.addEventListener(\"dragover\", this.boundFrameDragOver)")
    expect(source).to include("frameDocument.addEventListener(\"drop\", this.boundFrameDrop)")

    expect(source).to include("this.frameDocumentRef.removeEventListener(\"dragenter\", this.boundFrameDragEnter)")
    expect(source).to include("this.frameDocumentRef.removeEventListener(\"dragover\", this.boundFrameDragOver)")
    expect(source).to include("this.frameDocumentRef.removeEventListener(\"drop\", this.boundFrameDrop)")
    expect(source).to include("this.frameDocumentRef = null")
  end

  it "keeps missing or inaccessible iframe documents as no-op boundaries" do
    expect(source).to include("if (!this.hasFrameTarget) return null")
    expect(source).to include("try {\n      return this.frameTarget.contentDocument\n    } catch (_error) {\n      return null\n    }")
  end

  it "keeps single file iframe drops connected to the hidden multipart form flow" do
    expect(source).to include("frameDrop(event)")
    expect(source).to include("const file = this.singleFileFrom(event)")
    expect(source).to include("if (!file) return")
    expect(source).to include("this.upload(file, this.element)")

    expect(source).to include("const url = target.dataset.manualDocumentUploadUrl || this.urlValue")
    expect(source).to include("if (!url) return")
    expect(source).to include("form.method = \"post\"")
    expect(source).to include("form.enctype = \"multipart/form-data\"")
    expect(source).to include("this.appendHidden(form, \"source_path\", target.dataset.manualDocumentUploadSourcePath || this.sourcePathValue || \"\")")
    expect(source).to include("this.appendHidden(form, \"target_document_id\", target.dataset.manualDocumentUploadTargetDocumentId || \"\")")
    expect(source).to include("const transfer = new DataTransfer()")
    expect(source).to include("transfer.items.add(file)")
    expect(source).to include("form.submit()")
  end

  it "keeps multiple file drops as inline preview without browser alert or submit" do
    expect(source).to include("if (files.length > 1) {\n      this.showMultiFilePreview(files)\n      return null\n    }")
    expect(source).to include("this.clearMultiFilePreview()")
    expect(source).to include("static targets = [\"frame\", \"overlay\", \"multiFilePreview\", \"multiFileSummary\", \"multiFileNames\", \"multiFileOverflow\"]")
    expect(source).to include("const visibleFiles = files.slice(0, this.multiFilePreviewLimit)")
    expect(source).to include("item.textContent = file.name || \"名称未設定\"")
    expect(source).to include("ほか${overflowCount}件は表示していません。")
    expect(source).not_to include("window.alert")
  end

  it "keeps multi-file preview bounded to names and count only" do
    preview_source = source[/showMultiFilePreview\(files\) \{(.*?)\n  \}/m, 1]

    expect(preview_source).to include("files.length")
    expect(preview_source).to include("file.name")
    expect(preview_source).not_to include("file.size")
    expect(preview_source).not_to include("file.type")
    expect(preview_source).not_to include("file.lastModified")
    expect(preview_source).not_to include("file.webkitRelativePath")
  end
end
