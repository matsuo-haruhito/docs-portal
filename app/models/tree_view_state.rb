class TreeViewState < ApplicationRecord
  belongs_to :owner, polymorphic: true

  validates :tree_instance_key, presence: true
  validates :tree_instance_key, uniqueness: { scope: %i[owner_type owner_id] }
  validates :expanded_keys, presence: true, allow_blank: true
end
