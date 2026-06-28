# RTP x RFK document sets canary

この note は、#2740 の first slice として `admin/document_sets` を RTP x RFK bridge の代表 canary に固定するための evidence record です。

## Canary surface

- Screen: `admin/document_sets`
- RTP surface: table key `admin_document_sets`, stable column keys, column filter metadata, mounted preference save surface
- RFK surface: project combobox, set type / visibility policy select, document remote picker, fixed version picker, invalid rerender selected state
- Host app responsibility: query execution, authorization, endpoint scoping, validation rerender, `document_set_items` persistence

## Evidence

- Request spec: `spec/requests/admin_document_sets_rtp_rfk_bridge_spec.rb`
- Existing broader request spec: `spec/requests/admin_document_sets_spec.rb`
- View: `app/views/admin/document_sets/index.html.slim`
- Form: `app/views/admin/document_sets/_form.html.slim`
- Helper: `app/helpers/admin/document_sets_helper.rb`

## Boundary

- RFK owns field rendering metadata and selected-state wiring, but not query execution, authorization, endpoint policy, or persistence.
- RTP owns table preference metadata and stable table keys, but not RFK field rendering or validation rerender behavior.
- docs-portal owns admin-only routing, project/document scoping, filter params, document set item persistence, and business labels.

## Non-goals

- No `Gemfile` or pinned ref update.
- No upstream `rails_table_preferences` or `rails_fields_kit` API change.
- No all-admin-screen rollout.
- No table preference schema redesign.
- No replacement for #858 release train or #607 screen-by-screen adoption.

## Rollback note

If this canary becomes noisy, rollback is limited to the request spec and this evidence note. Runtime behavior is unchanged in this slice.
