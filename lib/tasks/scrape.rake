# frozen_string_literal: true

require_relative '../scraper'

namespace :coop do
  task scrape: :environment do
    puts '******************************** PAL SYSTEM'
    Scraper.new.pal_system
    puts '******************************** COOP DELI'
    Scraper.new.coop_deli
  end
end