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

  def to_json
    hash = attributes.slice(*%w[name price quantity total image_url category])
    if items = child_items.map(&:to_json).presence
      hash.merge!(child_items: items)
    end
    hash
  end

  class << self
    def zero_item_back
      all.to_a.partition { |item| item.quantity > 0 }.flatten
    end
  end
end
