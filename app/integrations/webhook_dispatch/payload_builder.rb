module WebhookDispatch
  class PayloadBuilder
    def initialize(event:)
      @event = event
    end

    def call
      {
        id: event.public_id,
        event_type: event.event_type,
        occurred_at: event.occurred_at.iso8601,
        title: event.title,
        body: event.body,
        project: event.project && { id: event.project.public_id, code: event.project.code, name: event.project.name },
        document: event.document && { id: event.document.public_id, slug: event.document.slug, title: event.document.title },
        document_version: event.document_version && { id: event.document_version.public_id, version_label: event.document_version.version_label },
        actor: event.actor_user && { id: event.actor_user.public_id, email_address: event.actor_user.email_address, name: event.actor_user.name }
      }.compact
    end

    private

    attr_reader :event
  end
end
