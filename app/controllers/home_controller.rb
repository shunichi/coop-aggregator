# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @old_deliveries = Delivery.within(1.week.ago.to_date..Date.yesterday).default_order.preload(:shop, root_items: :child_items)
    @deliveries = Delivery.after(Date.current).default_order.preload(:shop, root_items: :child_items)
    @deliveries_without_delivery_date = Delivery.without_delivery_date.order(:id).preload(:shop, root_items: :child_items)
  end

  def pwa
  end
end