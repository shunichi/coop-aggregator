class Shop < ApplicationRecord
  has_many :deliveries, dependent: :destroy
  validates :name, :display_name, presence: true
end
