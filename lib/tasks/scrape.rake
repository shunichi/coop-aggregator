# frozen_string_literal: true

require_relative '../scraper'

namespace :coop do
  task scrape: :environment do
    ActiveRecord::Base.logger = Logger.new(STDOUT)

    puts '******************************** COOP DELI'
    Scraper.new.coop_deli
    puts '******************************** PAL SYSTEM'
    Scraper.new.pal_system
  end
end