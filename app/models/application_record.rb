class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  private

  def broadcast_document_tree_refresh_later
    broadcast_refresh_later_to "document_tree"
  end
end
