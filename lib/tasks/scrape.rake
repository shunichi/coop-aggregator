# frozen_string_literal: true

require_relative '../scraper'

namespace :coop do
  task scrape: :environment do
    puts '******************************** PAL SYSTEM'
    Retryable.retryable(tries: 3, on: Scraper::APIError, exception_cb: -> (ex) { puts ex.message }) do
      Scraper.new.pal_system
    end
    puts '******************************** COOP DELI'
    Retryable.retryable(tries: 3, on: Scraper::APIError, exception_cb: -> (ex) { puts ex.message }) do
      Scraper.new.coop_deli
    end
  end
end