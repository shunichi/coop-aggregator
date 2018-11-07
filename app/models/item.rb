class Item < ApplicationRecord
  belongs_to :delivery
  validates :name, presence: true
  validates :price, :quantity, :total, numericality:  { greater_than_or_equal_to: 0 }
end
