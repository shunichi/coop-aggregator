class Item < ApplicationRecord
  belongs_to :delivery
  belongs_to :parent, class_name: 'Item', optional: true
  has_many :child_items, class_name: 'Item', foreign_key: 'parent_id', dependent: :destroy
  validates :name, presence: true
  validates :price, :quantity, :total, numericality:  { greater_than_or_equal_to: 0 }
end
