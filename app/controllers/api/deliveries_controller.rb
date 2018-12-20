# frozen_string_literal: true

class Api::DeliveriesController < Api::ApplicationController
  before_action :set_date_range

  def index
    @deliveries = Delivery
      .after(@date_begin)
      .before(@date_end)
      .default_order
      .preload(:shop, root_items: :child_items)
    respond_to :json
  end

  private

  def set_date_range
    @date_begin = 1.week.ago.to_date
    @date_end = nil
  end
end

