# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @deliveries = Delivery.after(Date.current).default_order.preload(:items, :shop)
    @deliveries_without_delivery_date = Delivery.without_delivery_date.order(:id).preload(:items, :shop)
  end
end