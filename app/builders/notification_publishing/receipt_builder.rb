module NotificationPublishing
  class ReceiptBuilder
    def initialize(event:)
      @event = event
    end

    def call(users:)
      users.each do |user|
        event.notification_receipts.find_or_create_by!(user:)
      end
    end

    private

    attr_reader :event
  end
end
