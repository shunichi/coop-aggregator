# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @old_deliveries = Delivery.within(1.week.ago.to_date..Date.yesterday).default_order.preload(:items, :shop)
    @deliveries = Delivery.after(Date.current).default_order.preload(:items, :shop)
    @deliveries_without_delivery_date = Delivery.without_delivery_date.order(:id).preload(:items, :shop)
  end
end