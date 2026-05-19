require "rails_helper"

RSpec.describe DocumentDiffHelper, type: :helper do
  Line = Struct.new(:kind, :old_number, :new_number, :text, keyword_init: true)

  it "highlights only the changed fragment between removed and added lines" do
    lines = [
      Line.new(kind: :removed, old_number: 1, new_number: nil, text: "title: old value"),
      Line.new(kind: :added, old_number: nil, new_number: 1, text: "title: new value")
    ]

    removed_html = helper.diff_line_code_with_inline_highlight(lines, 0)
    added_html = helper.diff_line_code_with_inline_highlight(lines, 1)

    expect(removed_html).to include("- title: ")
    expect(removed_html).to include('<mark class="diff-inline-change">old</mark>')
    expect(added_html).to include("+ title: ")
    expect(added_html).to include('<mark class="diff-inline-change">new</mark>')
  end

  it "keeps unchanged middle tokens unmarked when a line has multiple changed fragments" do
    lines = [
      Line.new(kind: :removed, old_number: 1, new_number: nil, text: "alpha old beta red gamma"),
      Line.new(kind: :added, old_number: nil, new_number: 1, text: "alpha new beta blue gamma")
    ]

    removed_html = helper.diff_line_code_with_inline_highlight(lines, 0)
    added_html = helper.diff_line_code_with_inline_highlight(lines, 1)

    expect(removed_html).to include('<mark class="diff-inline-change">old</mark> beta <mark class="diff-inline-change">red</mark>')
    expect(added_html).to include('<mark class="diff-inline-change">new</mark> beta <mark class="diff-inline-change">blue</mark>')
    expect(removed_html).not_to include('<mark class="diff-inline-change">old beta red</mark>')
  end

  it "escapes line text before highlighting" do
    lines = [
      Line.new(kind: :removed, old_number: 1, new_number: nil, text: "name: A < B"),
      Line.new(kind: :added, old_number: nil, new_number: 1, text: "name: A > B")
    ]

    html = helper.diff_line_code_with_inline_highlight(lines, 1)

    expect(html).to include("&gt;")
    expect(html).not_to include("name: A > B")
    expect(html).to include('class="diff-inline-change"')
  end

  it "renders context lines without inline marks" do
    lines = [Line.new(kind: :context, old_number: 1, new_number: 1, text: "same")]

    html = helper.diff_line_code_with_inline_highlight(lines, 0)

    expect(html).to include("  same")
    expect(html).not_to include("diff-inline-change")
  end
end
