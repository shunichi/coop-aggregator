# frozen_string_literal: true

#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load

PAL_USER_ID = ENV['PAL_USER_ID']
PAL_PASSWORD = ENV['PAL_PASSWORD']
PAL_API_URL = ENV['PAL_API_URL']
DELI_USER_ID = ENV['DELI_USER_ID']
DELI_PASSWORD = ENV['DELI_PASSWORD']
DELI_API_URL = ENV['DELI_API_URL']

class Scraper
  class APIError < StandardError
  end

  class CloudFunctionApiClient
    def self.post(api_url, id, password)
      self.new(api_url, id, password).post
    end

    def initialize(endpoint, id, password)
      @uri = URI.parse(endpoint)
      @id = id
      @password = password
    end

    def post
      http = Net::HTTP.new(@uri.host, @uri.port).tap { |h| h.use_ssl = @uri.scheme == 'https' }
      http.read_timeout = 150
      request = Net::HTTP::Post.new(@uri.request_uri, headers)
      request.body = { id: @id, password: @password }.to_json
      response = http.request(request)
      if response.code == '200'
        JSON.parse(response.body).deep_symbolize_keys
      else
        raise APIError, response.body
      end
    end

    private

    def headers
      { 'Content-Type' => 'application/json' }
    end
  end

  def pal_system
    json = CloudFunctionApiClient.post(PAL_API_URL, PAL_USER_ID, PAL_PASSWORD)
    shop = Shop.find_by!(name: 'pal-system')
    json[:deliveryDates].each do |data|
      shop.deliveries.create_with(name: data[:name]).find_or_create_by!(delivery_date: data[:deliveryDate])
      puts data
    end
    json[:orders].each do |order|
      delivery_name = order[:name]
      delivery = shop.deliveries.find_or_create_by!(name: delivery_name)
      puts "***** #{delivery_name}"
      puts order[:items]
      update_items!(delivery, order[:items])
    end
  end

  def coop_deli
    json = CloudFunctionApiClient.post(DELI_API_URL, DELI_USER_ID, DELI_PASSWORD)
    shop = Shop.find_by!(name: 'coop-deli')
    json[:orders].each do |order|
      delivery_name = order[:name] || order[:deliveryName]
      delivery_date = order[:deliveryDate]
      delivery = shop.deliveries.create_with(delivery_date: delivery_date).find_or_create_by!(name: delivery_name)
      puts "***** #{delivery_name}"
      puts order[:items]
      update_items!(delivery, order[:items])
    end
  end

  def update_item!(delivery, parent_item, attributes)
    item = delivery.items
      .find_or_create_by!(name: attributes[:name])
    category =
      if attributes[:cold]
        'cold'
      elsif attributes[:frozen]
        'frozen'
      end
    item_attributes = {
      parent_id: parent_item&.id,
      quantity: attributes[:quantity].to_i,
      price: attributes[:price].to_i,
      total: attributes[:total].to_i,
      image_url: attributes[:imageUrl],
      category: category,
    }.compact
    item.update!(item_attributes)
    if attributes[:children]
      attributes[:children].each do |child_attributes|
        update_item!(delivery, item, child_attributes)
      end
    end
    item
  end

  def update_items!(delivery, scraped_items)
    scraped_names = scraped_items.flat_map do |attributes|
      [attributes[:name]] + Array(attributes[:children]).map { |child| child[:name] }
    end.to_set
    Item.transaction do
      delivery.items.each do |item|
        unless scraped_names.member?(item.name)
          puts "destroy '#{item.name}'"
          item.destroy!
        end
      end
      scraped_items.each do |attributes|
        update_item!(delivery, nil, attributes)
      end
    end
  end
end