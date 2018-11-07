class Delivery < ApplicationRecord
  belongs_to :shop
  has_many :items, dependent: :destroy
  validates :name, presence: true

  scope :without_delivery_date, -> { where(delivery_date: nil) }
  scope :after, -> (date) { where('delivery_date >= ?', date) }
  scope :default_order, -> { order(:delivery_date) }
end
