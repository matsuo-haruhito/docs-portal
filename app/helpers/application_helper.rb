module ApplicationHelper
  def page_title(*parts)
    content_for :title, parts.compact.join(" | ")
  end

  def localized_label(scope, value)
    value = value.to_s
    I18n.t("labels.#{scope}.#{value}", default: value)
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
              tag.td("（なし）", colspan:, class: "muted")
            end
          end
        ])
      else
        content
      end
    end
  end
end
