require "fileutils"
require "pathname"
require "zlib"

module SeedSupport
  class SeedSampleDocumentGenerator
    SAMPLE_SET = "seed-showcase".freeze
    SITE = "docs-portal-demo".freeze
    PREVIOUS = "提出済".freeze

    def initialize(root: Rails.root.join("storage", "document_files", "external_samples"))
      @root = Pathname(root)
    end

    def run
      FileUtils.rm_rf(site_root)
      write_current
      write_previous
    end

    private

    attr_reader :root

    def site_root = root.join(SAMPLE_SET, SITE)
    def current_root = site_root
    def previous_root = site_root.join(PREVIOUS)

    def write_current
      write_text(current_root.join("README.md"), current_readme)
      write_text(current_root.join("runbook.md"), runbook_md)
      write_text(current_root.join("process.mmd"), mermaid)
      write_text(current_root.join("runbook.csv"), csv)
      write_binary(current_root.join("README.pdf"), pdf)
      write_binary(current_root.join("README.xlsx"), xlsx)
    end

    def write_previous
      write_text(previous_root.join("README.md"), previous_readme)
    end

    def write_text(path, content)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, content, encoding: "UTF-8")
    end

    def write_binary(path, content)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content)
    end

    def current_readme
      <<~MD
        # サンプル文書ポータル標準セット

        主要な閲覧・検索・ダウンロード機能を少ない文書数で確認するための seed サンプルです。
        PDF と Excel は各 1 件に絞り、Markdown 内に表、Mermaid、PlantUML 記法、添付ファイルリンクを含めています。

        | 観点 | サンプル | 期待する確認 |
        | --- | --- | --- |
        | Markdown | このページ | 見出し、表、リンク、コードブロックが崩れない |
        | Mermaid | 下の `flowchart` と `process.mmd` | 図表を含む文書導線を確認できる |
        | PlantUML | 下の text ブロック | Kroki 未設定でも記法サンプルを確認できる |
        | PDF | `README.pdf` | PDF プレビューまたはダウンロードを確認できる |
        | Excel | `README.xlsx` | Office/Excel 系ファイルの導線を確認できる |
        | CSV | `runbook.csv` | CSV プレビューを確認できる |
        | 複数版 | `提出済` スナップショット | 旧版と current の切り替えを確認できる |

        ```mermaid
        flowchart LR
          A[Markdown を編集] --> B[seed で取り込み]
          B --> C[ポータルで閲覧]
          C --> D{添付あり?}
          D -->|PDF| E[PDF を確認]
          D -->|Excel| F[表形式資料を確認]
        ```

        ```text
        @startuml
        actor 利用者
        participant "Docs Portal" as Portal
        database "DocumentFile" as File
        利用者 -> Portal: 文書を開く
        Portal -> File: 添付ファイル一覧を取得
        File --> Portal: PDF / Excel / CSV
        Portal --> 利用者: プレビューまたはダウンロード
        @enduml
        ```

        ## 添付ファイル

        - [サンプルPDF](./README.pdf)
        - [サンプルExcel](./README.xlsx)
        - [運用CSV](./runbook.csv)
      MD
    end

    def runbook_md
      <<~MD
        # 運用確認 Runbook

        - 文書ツリーに標準セットとこの Runbook が表示される
        - `current` と `提出済` の複数版を切り替えられる
        - PDF / Excel / CSV がそれぞれ異なるファイル種別として扱われる
      MD
    end

    def previous_readme
      <<~MD
        # サンプル文書ポータル標準セット（提出済）

        これは複数版確認用の旧版です。

        | 版 | 状態 | 備考 |
        | --- | --- | --- |
        | 提出済 | published | 旧版表示の確認用 |
        | current | published | PDF 1 件、Excel 1 件、CSV 1 件を含む |
      MD
    end

    def mermaid
      <<~MMD
        flowchart TD
          seed[db:seed] --> generate[サンプル生成]
          generate --> import[外部サンプル取り込み]
          import --> versions[複数版文書]
          import --> files[PDF / Excel / CSV]
          versions --> portal[ポータル確認]
          files --> portal
      MMD
    end

    def csv
      <<~CSV
        step,actor,expected
        1,admin@example.com,文書ツリーを開ける
        2,viewer@example.com,公開文書を閲覧できる
        3,external@example.com,許可された添付ファイルをダウンロードできる
      CSV
    end

    def pdf
      stream = "BT\n/F1 12 Tf\n72 740 Td\n(Docs Portal seed sample) Tj\n0 -18 Td (One PDF is enough for preview checks.) Tj\nET\n"
      objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        "<< /Length #{stream.bytesize} >>\nstream\n#{stream}endstream"
      ]
      body = +"%PDF-1.4\n"
      offsets = [0]
      objects.each_with_index do |object, index|
        offsets << body.bytesize
        body << "#{index + 1} 0 obj\n#{object}\nendobj\n"
      end
      xref = body.bytesize
      body << "xref\n0 #{objects.length + 1}\n0000000000 65535 f \n"
      offsets.drop(1).each { |offset| body << format("%010d 00000 n \n", offset) }
      body << "trailer\n<< /Size #{objects.length + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
      body.b
    end

    def xlsx
      ZipStore.build(
        "[Content_Types].xml" => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
        "_rels/.rels" => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
        "xl/workbook.xml" => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"SeedSample\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
        "xl/_rels/workbook.xml.rels" => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
        "xl/worksheets/sheet1.xml" => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>確認項目</t></is></c><c r=\"B1\" t=\"inlineStr\"><is><t>ファイル</t></is></c><c r=\"C1\" t=\"inlineStr\"><is><t>期待結果</t></is></c></row><row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>PDF</t></is></c><c r=\"B2\" t=\"inlineStr\"><is><t>README.pdf</t></is></c><c r=\"C2\" t=\"inlineStr\"><is><t>PDF として認識</t></is></c></row></sheetData></worksheet>"
      )
    end
  end

  class ZipStore
    def self.build(entries) = new(entries).build

    def initialize(entries)
      @entries = entries
    end

    def build
      output = +"".b
      central = +"".b
      @entries.each do |name, content|
        data = content.to_s.b
        filename = name.to_s.b
        crc = Zlib.crc32(data)
        offset = output.bytesize
        output << [0x04034b50, 20, 0, 0, 0, 0, crc, data.bytesize, data.bytesize, filename.bytesize, 0].pack("VvvvvvVVVvv") << filename << data
        central << [0x02014b50, 20, 20, 0, 0, 0, 0, crc, data.bytesize, data.bytesize, filename.bytesize, 0, 0, 0, 0, 0, offset].pack("VvvvvvvVVVvvvvvVV") << filename
      end
      offset = output.bytesize
      output << central
      output << [0x06054b50, 0, 0, @entries.length, @entries.length, central.bytesize, offset, 0].pack("VvvvvVVv")
      output
    end
  end
end
