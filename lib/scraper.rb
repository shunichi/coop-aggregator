# frozen_string_literal: true

#!/usr/bin/env ruby

require 'capybara'
require 'date'
require 'fileutils'
require 'dotenv'
Dotenv.load

PAL_USER_ID = ENV['PAL_USER_ID']
PAL_PASSWORD = ENV['PAL_PASSWORD']
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

  def pal_system
    shop = Shop.find_by!(name: 'pal-system')

    session = Capybara.current_session
    session.visit 'https://shop.pal-system.co.jp/iplg/login.htm?PROC_DIV=1'
    result = Capybara::Screenshot.screenshot_and_save_page
    p result
    id_field = session.find(:xpath, '//div[@class="fieldset"][contains(., "ID")]//input')
    id_field.set(PAL_USER_ID)
    session.fill_in 'password', with: PAL_PASSWORD
    session.click_link 'ログイン'
    session.assert_text 'Myメニュー'

    # このページを経由しないとエラーになる
    session.visit 'https://shop.pal-system.co.jp/ipsc/restTermEntry.htm'
    session.assert_text 'お休みを申し込む'

    # 配達回と配達日の対応を取得
    # お休みの申し込みなら配達日が表示される。でも未来しか見えない。
    session.visit 'https://shop.pal-system.co.jp/ipsc/restTermInput.htm'
    session.assert_text 'ご注文のお休みを開始する企画回'

    today = Date.today
    delivery_days = session.all('.list-input.orderRest .col.title').map do |node|
      # 1月4回　2月2日(金)お届け商品分
      if m = /\A((\d+)月.+?)　(\d+)月(\d+)日/.match(node.text)
        name_month = m[2].to_i
        name_year = today.month <= name_month ? today.year : today.year + 1
        month = m[3].to_i
        day = m[4].to_i
        date = Date.new(today.month <= month ? today.year : today.year + 1, month, day)
        { year: name_year, name: m[1], delivery_date: date }
      else
        raise %("#{node.text}" does not match!)
      end
    end
    puts delivery_days
    delivery_days.each do |day|
      shop.deliveries.create_with(name: day[:name]).find_or_create_by!(delivery_date: day[:delivery_date])
    end

    # 注文
    session.visit 'https://shop.pal-system.co.jp/pal/OrderReferenceDirect.do'
    session.assert_text '注文履歴'

    write_html(session, 'tmp/pal.html')

    doc = Nokogiri::HTML.parse(session.html)
    title = doc.xpath("//div[@class='section record']/h2").text.gsub(/\s+/, ' ').strip
    delivery_name = title.gsub(/(\d+月\d回).*/, '\1')
    puts title
    puts delivery_name
    scraped_items = doc.xpath("//table[contains(@class,'order-table1')]/tbody/tr[td[contains(@class,'item')]]").map do |node|
      {
        name: node.xpath("td[contains(@class,'item')]").text.gsub(/\s+/, ' ').strip,
        quantity: node.xpath("td[@class='quantity']").text.gsub(/(\s+|,)/, '').to_i,
        price: node.xpath("td[@class='price']").text.gsub(/(\s+|,)/, '').to_i,
        total: node.xpath("td[@class='total']").text.gsub(/(\s+|,)/, '').to_i,
      }
    end
    puts scraped_items
    delivery = shop.deliveries.where(name: delivery_name).where('delivery_date IS NULL OR delivery_date >= ?', Date.current).order(:id).last
    delivery ||= shop.deliveries.create!(name: delivery_name)
    update_items!(delivery, scraped_items)
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