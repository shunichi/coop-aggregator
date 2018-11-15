class Delivery < ApplicationRecord
  belongs_to :shop
  has_many :items, dependent: :destroy
  validates :name, presence: true

  scope :without_delivery_date, -> { where(delivery_date: nil) }
  scope :after, -> (date) { where('delivery_date >= ?', date) }
  scope :within, -> (date_range) { where(':date_begin <= delivery_date AND delivery_date <= :date_end', date_begin: date_range.begin, date_end: date_range.end)}
  scope :default_order, -> { order(:delivery_date) }
end
