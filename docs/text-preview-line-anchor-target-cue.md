# Text Preview Line Anchor Target Cue

This note supports `docs/版詳細プレビュー・差分・添付確認runbook.md` without redefining the preview workflow.

## How To Read The Cue

- A `line anchor target` opened through a hash link uses the blue cue from `.line-preview__row:target` / `.is-text-preview-anchor-target`.
- A `search match` uses the yellow cue from `.is-text-preview-match`.
- When both concepts are relevant during review, read the blue cue as the current deep-link destination and the yellow cue as the search result state.
- The target row also receives `aria-current="location"`, so assistive technology can identify the current line without adding visible text inside the row.

## Boundaries

- Current behavior remains unchanged for `/` search focus, `Escape` clear, match filtering, copy, and `hashchange` updates.
- This note does not add a new line anchor generation policy, server-side search, parser behavior, copy/export contract, or preview toolbar redesign.
- Visible row labels are intentionally not added, so line numbers and preview text keep the same layout density.
