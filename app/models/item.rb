# frozen_string_literal: true

class Item < ApplicationRecord
  extend Enumerize
  belongs_to :delivery
  belongs_to :parent, class_name: 'Item', optional: true
  has_many :child_items, class_name: 'Item', foreign_key: 'parent_id', dependent: :destroy
  CATEGORIES = [
    CATEGORY_NONE = 'none',
    CATEGORY_COLD = 'cold',
    CATEGORY_FROZEN = 'frozen',
  ].freeze
  enumerize :category, in: CATEGORIES
  validates :name, :category, presence: true
  validates :price, :quantity, :total, numericality:  { greater_than_or_equal_to: 0 }
end
