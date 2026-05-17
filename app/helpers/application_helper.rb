module ApplicationHelper
  def page_title(*parts)
    content_for :title, parts.compact.join(" | ")
  end

  def localized_label(scope, value, **interpolations)
    value = value.to_s
    I18n.t("labels.#{scope}.#{value}", **interpolations.except(:default), default: value)
  end

  def enum_options_for(scope, values)
    values.map { |value| [localized_label(scope, value), value] }
  end

  def user_type_label(user_or_value)
    value = user_or_value.respond_to?(:user_type) ? user_or_value.user_type : user_or_value
    localized_label("users.user_type", value)
  end

  def project_membership_role_label(membership_or_value)
    value = membership_or_value.respond_to?(:role) ? membership_or_value.role : membership_or_value
    localized_label("project_memberships.role", value)
  end

  def document_set_type_label(document_set_or_value)
    value = document_set_or_value.respond_to?(:set_type) ? document_set_or_value.set_type : document_set_or_value
    localized_label("document_sets.set_type", value)
  end

  def document_set_visibility_policy_label(document_set_or_value)
    value = document_set_or_value.respond_to?(:visibility_policy) ? document_set_or_value.visibility_policy : document_set_or_value
    localized_label("document_sets.visibility_policy", value)
  end

  def document_category_label(document_or_value)
    value = document_or_value.respond_to?(:category) ? document_or_value.category : document_or_value
    localized_label("documents.category", value)
  end

  def document_kind_label(document_or_value)
    value = document_or_value.respond_to?(:document_kind) ? document_or_value.document_kind : document_or_value
    localized_label("documents.document_kind", value)
  end

  def document_visibility_policy_label(document_or_value)
    value = document_or_value.respond_to?(:visibility_policy) ? document_or_value.visibility_policy : document_or_value
    localized_label("documents.visibility_policy", value)
  end

  def document_importance_level_label(document_or_value)
    value = document_or_value.respond_to?(:importance_level) ? document_or_value.importance_level : document_or_value
    localized_label("documents.importance_level", value)
  end

  def document_permission_access_level_label(permission_or_value)
    value = permission_or_value.respond_to?(:access_level) ? permission_or_value.access_level : permission_or_value
    localized_label("document_permissions.access_level", value)
  end

  def document_version_status_label(version_or_value)
    value = version_or_value.respond_to?(:status) ? version_or_value.status : version_or_value
    localized_label("document_versions.status", value)
  end

  def document_version_label(version)
    localized_label("document_versions.version_label", version.version_label)
  end

  def document_version_snapshot_kind_label(version_or_value)
    value = version_or_value.respond_to?(:snapshot_kind) ? version_or_value.snapshot_kind : version_or_value
    localized_label("document_versions.snapshot_kind", value)
  end

  def document_review_comment_type_label(comment_or_value)
    value = comment_or_value.respond_to?(:comment_type) ? comment_or_value.comment_type : comment_or_value
    localized_label("document_review_comments.comment_type", value)
  end

  def document_review_comment_status_label(comment_or_value)
    value = comment_or_value.respond_to?(:status) ? comment_or_value.status : comment_or_value
    localized_label("document_review_comments.status", value)
  end

  def document_approval_request_status_label(request_or_value)
    value = request_or_value.respond_to?(:status) ? request_or_value.status : request_or_value
    localized_label("document_approval_requests.status", value)
  end

  def document_relation_type_label(result_or_value)
    value = result_or_value.respond_to?(:relation_type) ? result_or_value.relation_type : result_or_value
    localized_label("document_relations.relation_type", value)
  end

  def access_log_action_type_label(log_or_value)
    value = log_or_value.respond_to?(:action_type) ? log_or_value.action_type : log_or_value
    localized_label("access_logs.action_type", value)
  end

  def access_log_target_type_label(log_or_value)
    value = log_or_value.respond_to?(:target_type) ? log_or_value.target_type : log_or_value
    localized_label("access_logs.target_type", value)
  end

  def consent_scope_label(term_or_value)
    value = term_or_value.respond_to?(:consent_scope) ? term_or_value.consent_scope : term_or_value
    localized_label("consent_terms.consent_scope", value)
  end

  def consent_requirement_timing_label(term_or_value)
    value = term_or_value.respond_to?(:requirement_timing) ? term_or_value.requirement_timing : term_or_value
    localized_label("consent_terms.requirement_timing", value)
  end

  def git_import_source_provider_label(source_or_value)
    value = source_or_value.respond_to?(:provider) ? source_or_value.provider : source_or_value
    localized_label("git_import_sources.provider", value)
  end

  def git_import_source_auth_type_label(source_or_value)
    value = source_or_value.respond_to?(:auth_type) ? source_or_value.auth_type : source_or_value
    localized_label("git_import_sources.auth_type", value)
  end

  def git_import_run_import_mode_label(run_or_value)
    value = run_or_value.respond_to?(:import_mode) ? run_or_value.import_mode : run_or_value
    localized_label("git_import_runs.import_mode", value)
  end

  def git_import_run_status_label(run_or_value)
    value = run_or_value.respond_to?(:status) ? run_or_value.status : run_or_value
    localized_label("git_import_runs.status", value)
  end

  def microsoft_graph_connection_auth_type_label(connection_or_value)
    value = connection_or_value.respond_to?(:auth_type) ? connection_or_value.auth_type : connection_or_value
    localized_label("microsoft_graph_connections.auth_type", value)
  end

  def external_folder_sync_source_provider_label(source_or_value)
    value = source_or_value.respond_to?(:provider) ? source_or_value.provider : source_or_value
    localized_label("external_folder_sync_sources.provider", value)
  end

  def external_folder_sync_source_auth_type_label(source_or_value)
    value = source_or_value.respond_to?(:auth_type) ? source_or_value.auth_type : source_or_value
    localized_label("external_folder_sync_sources.auth_type", value)
  end

  def external_folder_sync_source_sync_direction_label(source_or_value)
    value = source_or_value.respond_to?(:sync_direction) ? source_or_value.sync_direction : source_or_value
    localized_label("external_folder_sync_sources.sync_direction", value)
  end

  def external_folder_sync_source_conflict_policy_label(source_or_value)
    value = source_or_value.respond_to?(:conflict_policy) ? source_or_value.conflict_policy : source_or_value
    localized_label("external_folder_sync_sources.conflict_policy", value)
  end

  def external_folder_sync_run_status_label(run_or_value)
    value = run_or_value.respond_to?(:status) ? run_or_value.status : run_or_value
    localized_label("external_folder_sync_runs.status", value)
  end

  def external_folder_sync_run_mode_label(run_or_value)
    value = run_or_value.respond_to?(:mode) ? run_or_value.mode : run_or_value
    localized_label("external_folder_sync_runs.mode", value)
  end

  def external_folder_sync_run_safety_label(run)
    localized_label("external_folder_sync_runs.safety_state", external_folder_sync_run_safety_state(run))
  end

  def external_folder_sync_run_safety_class(run)
    case external_folder_sync_run_safety_state(run)
    when :blocked then "status-danger"
    when :approved, :warning then "status-warning"
    else "muted"
    end
  end

  def external_folder_sync_run_safety_state(run)
    return :not_run if run.blank?

    summary = run.summary_json || {}
    return :blocked if summary.fetch("blocked_by_conflict_warnings", false)
    return :approved if summary.fetch("conflict_warnings_allowed", false)
    return :warning if summary.fetch("conflict_warnings_count", 0).to_i.positive?

    :normal
  end

  def external_folder_sync_run_has_conflict_warnings?(run)
    run.present? && run.summary_json&.fetch("conflict_warnings_count", 0).to_i.positive?
  end

  def external_folder_sync_run_warning_dry_run?(run)
    run.present? && run.dry_run? && external_folder_sync_run_has_conflict_warnings?(run)
  end

  def external_folder_sync_force_apply_visible?(run)
    external_folder_sync_run_warning_dry_run?(run) && !external_folder_sync_approved?(run)
  end

  def external_folder_sync_approval_summary(run)
    return {} if run.blank?

    run.summary_json&.fetch("conflict_warnings_approval", nil) || {}
  end

  def external_folder_sync_approval_actor_label(run)
    approval = external_folder_sync_approval_summary(run)
    approval["actor_name"].presence || approval["actor_email"].presence || approval["actor_public_id"].presence || localized_label("external_folder_sync_runs.approval", "fallback")
  end

  def external_folder_sync_approval_approved_at(run)
    external_folder_sync_approval_summary(run)["approved_at"].presence
  end

  def external_folder_sync_approved?(run)
    external_folder_sync_approval_summary(run).present?
  end

  def external_folder_sync_item_status_label(item_or_value)
    value = item_or_value.respond_to?(:sync_status) ? item_or_value.sync_status : item_or_value
    localized_label("external_folder_sync_items.sync_status", value)
  end

  def external_folder_sync_subscription_status_label(subscription_or_value)
    value = subscription_or_value.respond_to?(:status) ? subscription_or_value.status : subscription_or_value
    localized_label("external_folder_sync_subscriptions.status", value)
  end

  def external_folder_sync_webhook_event_status_label(event_or_value)
    value = event_or_value.respond_to?(:status) ? event_or_value.status : event_or_value
    localized_label("external_folder_sync_webhook_events.status", value)
  end

  def external_folder_sync_webhook_header(event, header_name)
    event.headers_json&.fetch(header_name, nil).presence || "-"
  end

  def external_folder_sync_webhook_sync_run_summary(event)
    event.payload_json&.fetch("sync_run", nil) || {}
  end

  def external_folder_sync_webhook_sync_run_label(event)
    summary = external_folder_sync_webhook_sync_run_summary(event)
    summary["public_id"].presence || summary["id"].presence || "-"
  end

  def external_folder_sync_webhook_sync_run_status(event)
    value = external_folder_sync_webhook_sync_run_summary(event)["status"]
    value.present? ? external_folder_sync_run_status_label(value) : nil
  end

  def external_folder_sync_webhook_sync_run_warnings_count(event)
    external_folder_sync_webhook_sync_run_summary(event)["conflict_warnings_count"].to_i
  end

  def external_folder_sync_webhook_sync_run_warning_label(event)
    count = external_folder_sync_webhook_sync_run_warnings_count(event)
    count.positive? ? localized_label("external_folder_sync_webhook_events", "sync_run_warning_label", count:) : nil
  end

  def external_folder_sync_webhook_sync_run_link_title(_event)
    localized_label("external_folder_sync_webhook_events", "sync_run_link_title")
  end

  def external_folder_sync_webhook_sync_run_link_aria_label(event)
    localized_label(
      "external_folder_sync_webhook_events",
      "sync_run_link_aria_label",
      run_id: external_folder_sync_webhook_sync_run_label(event)
    )
  end

  def external_folder_sync_webhook_sync_run_present?(event)
    external_folder_sync_webhook_sync_run_summary(event).present?
  end

  def external_folder_sync_plan_action_label(plan_or_value)
    value = plan_or_value.respond_to?(:[]) ? plan_or_value["action"] : plan_or_value
    localized_label("external_folder_sync_plans.action", value)
  end

  def external_folder_sync_plan_attention_label(plan_or_value)
    value = plan_or_value.respond_to?(:[]) ? plan_or_value["attention_level"] : plan_or_value
    localized_label("external_folder_sync_plans.attention_level", value.presence || "none")
  end

  def external_folder_sync_plan_attention_class(plan_or_value)
    value = plan_or_value.respond_to?(:[]) ? plan_or_value["attention_level"] : plan_or_value

    case value.to_s
    when "danger" then "status-danger"
    when "warning" then "status-warning"
    when "info" then "status-info"
    else "muted"
    end
  end

  def external_folder_sync_change_reasons(plan_or_item)
    reasons = if plan_or_item.respond_to?(:[])
      plan_or_item["change_reasons"]
    else
      plan_or_item.provider_metadata&.fetch("last_change_reasons", nil)
    end

    Array(reasons).compact_blank
  end

  def external_folder_sync_conflict_warnings(plan_or_item)
    warnings = if plan_or_item.respond_to?(:[])
      plan_or_item["conflict_warnings"]
    else
      plan_or_item.provider_metadata&.fetch("last_conflict_warnings", nil)
    end

    Array(warnings).compact_blank
  end

  def external_folder_sync_plan_reasons(plan_or_item)
    external_folder_sync_change_reasons(plan_or_item) + external_folder_sync_conflict_warnings(plan_or_item)
  end

  def bulk_edit_dry_run_status_label(run_or_value)
    value = run_or_value.respond_to?(:status) ? run_or_value.status : run_or_value
    localized_label("bulk_edit_dry_runs.status", value)
  end

  def boolean_label(value)
    value ? "はい" : "いいえ"
  end

  def bulk_edit_field_label(field)
    localized_label("bulk_edit_fields", field)
  end

  # テーブルが空でも、画面上で空状態と分かる行を補います。
  def table_tag(**options)
    options[:class] ||= %w[table]

    tag.table(**options) do
      content = capture { yield }
      content_string = content.to_s

      if content_string.match?(/\A\s*<thead.*<tbody>\s*<\/tbody>\s*\z/m)
        thead = content_string.sub(/<tbody>\s*<\/tbody>\s*\z/m, "")
        colspan = [thead.scan(/<th(?:\s|>)/).size, 1].max

        safe_join([
          thead.html_safe,
          tag.tbody do
            tag.tr do
              tag.td(localized_label("table", "empty"), colspan:, class: "muted")
            end
          end
        ])
      else
        content
      end
    end
  end
end
