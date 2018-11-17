# frozen_string_literal: true

#!/usr/bin/env ruby

require 'capybara'
require 'date'
require 'fileutils'
require 'dotenv'
Dotenv.load

PAL_USER_ID = ENV['PAL_USER_ID']
PAL_PASSWORD = ENV['PAL_PASSWORD']
PAL_API_URL = ENV['PAL_API_URL']
DELI_USER_ID = ENV['DELI_USER_ID']
DELI_PASSWORD = ENV['DELI_PASSWORD']

def write_html(session, filename)
  FileUtils.mkdir_p('tmp')
  IO.write(filename, session.html)
end

Capybara::Screenshot.autosave_on_failure = false
Capybara::Screenshot.s3_configuration = {
  s3_client_credentials: {
    access_key_id: ENV.fetch('AWS_S3_ACCESS_KEY_ID'),
    secret_access_key: ENV.fetch('AWS_S3_SECRET_KEY'),
    region: ENV.fetch('AWS_S3_REGION'),
  },
  bucket_name: ENV.fetch('AWS_S3_BUCKET_NAME')
}
Capybara::Screenshot.s3_object_configuration = {
  acl: 'public-read'
}

# # puts '************************************* COOP DELI'
# coop_deli
# puts '************************************* PAL SYSTEM'
# pal_system

class Scraper
  attr_reader :delivery_days, :scraped_items

  def initialize(driver = :selenium_chrome_headless)
    @driver = driver
    Capybara.current_driver = driver
    Capybara.save_path = 'tmp/capybara'
  end

  class APIError < StandardError
  end

  class Client
    def self.post
      self.new(PAL_API_URL).post
    end

    def initialize(endpoint)
      @uri = URI.parse(endpoint)
    end

    def post
      http = Net::HTTP.new(@uri.host, @uri.port).tap { |h| h.use_ssl = @uri.scheme == 'https' }
      http.read_timeout = 150
      request = Net::HTTP::Post.new(@uri.request_uri, headers)
      request.body = { id: PAL_USER_ID, password: PAL_PASSWORD }.to_json
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
    json = Client.post
    shop = Shop.find_by!(name: 'pal-system')
    json[:deliveryDates].each do |data|
      shop.deliveries.create_with(name: data[:name]).find_or_create_by!(delivery_date: data[:deliveryDate])
      puts data
    end
    json[:orders].each do |order|
      delivery_name = order[:name]
      # TODO パルシステムでも 2018年11月2回 というような名前になるようにする
      delivery = shop.deliveries.find_or_create_by!(name: delivery_name)
      puts "***** #{delivery_name}"
      puts order[:items]
      update_items!(delivery, order[:items])
    end
  end

  def coop_deli
    shop = Shop.find_by!(name: 'coop-deli')

    session = Capybara.current_session
    session.visit 'https://weekly.coopdeli.jp/order/index.html'

    if /メンテナンスのお知らせ/.match(session.html)
      puts 'メンテナンス中'
      return
    end

    # fill_in だとなぜか組合員コードが1桁抜けて入力されてしまうので、javascriptで入力する
    # session.fill_in 'j_username', with: '2434126268'
    session.execute_script %(document.querySelector('input[name="j_username"]').value = '#{DELI_USER_ID}')
    session.fill_in 'j_password', with: DELI_PASSWORD
    session.find('.FW_submitLink').click

    # 週選択
    osk_options = session.all('select[name="osk"] option')
    osks = osk_options.map { |node| node['value'] }
    odc = session.find('input[name="curodc"]', visible: false).value

    # window = session.window_opened_by do
    #   session.click_link '印刷画面へ'
    # end
    # session.switch_to_window window

    osk = osks.first
    osks.first(3).each do |osk|
      unless m = /\A(\d{4})(\d{2})(\d{2})\z/.match(osk)
        raise "osk mismatch: #{osk}"
      end
      name_year = m[1].to_i
      name_month = m[2].to_i
      name_time = m[3].to_i
      # "2018年１月５回" のような文字列で印刷ページがひらいたことを確認
      dalivery_name = "#{m[1]}年" + "#{m[2].to_i}月#{m[3].to_i}回".tr('0-9', '０-９')
      session.visit "https://weekly.coopdeli.jp/order/print.html?osk=#{osk}&odc=#{odc}"
      session.assert_title '注文確認（印刷用）｜ウイークリーコープ'
      session.assert_text dalivery_name

      # write_html(session, 'tmp/deli.html')

      doc = Nokogiri::HTML.parse(session.html)
      date = doc.xpath("//div[@class='cartWeekOrder']/dl/dd[1]").text
      scraped_items = doc.xpath("//tr[not(@class) and td[@class='cartItemDetail']]").map do |node|
        {
          name: node.xpath("td[@class='cartItemDetail']/p").text.strip,
          quantity: node.xpath("td[@class='cartItemQty']").text.gsub(/(\s+|,)/, '').to_i,
          price: node.xpath("td[@class='cartItemLot']").text.gsub(/(\s+|,)/, '').to_i,
          total: node.xpath("td[@class='cartItemPrice']").text.gsub(/(\s+|,)/, '').to_i,
        }
      end
      scraped_names = scraped_items.map { |i| i[:name] }.to_set

      delivery_name = "#{name_year}年#{name_month}月#{name_time}回"
      today = Date.today
      unless m = /(\d+)月(\d+)日/.match(date)
        raise "date mismatch: #{date}"
      end
      month = m[1].to_i
      day = m[2].to_i
      delivery_date = Date.new( month < today.month ? today.year + 1 : today.year, month, day)
      puts "***** #{delivery_name}: #{date} (#{delivery_date})"
      puts scraped_items
      delivery = shop.deliveries.create_with(delivery_date: delivery_date).find_or_create_by!(name: delivery_name)
      update_items!(delivery, scraped_items)
    end
  end

  def update_items!(delivery, scraped_items)
    scraped_names = scraped_items.map { |i| i[:name] }.to_set
    Item.transaction do
      delivery.items.each do |item|
        unless scraped_names.member?(item.name)
          item.destroy!
        end
      end
      scraped_items.each do |i|
        item = delivery.items
          .find_or_create_by!(name: i[:name])
        item.update!(quantity: i[:quantity].to_i, price: i[:price].to_i, total: i[:total].to_i)
      end
    end
  end
end