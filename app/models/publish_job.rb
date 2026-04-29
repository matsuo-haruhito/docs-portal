class PublishJob < ApplicationRecord
  enum :status, { pending: 0, imported: 1, published: 2, failed: 3 }
end
