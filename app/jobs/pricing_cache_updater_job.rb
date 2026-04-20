class PricingCacheUpdaterJob < ApplicationJob
  queue_as :default
  CACHE_TTL = 5.minutes

  def perform
    puts 'in job'

    attributes_with_rates = RateApiClient.get_all_rates(attributes: all_keys)

    if attributes_with_rates.success?
      puts 'success'
      parsed_rates = JSON.parse(attributes_with_rates.body)["rates"]

      parsed_rates.each do |key|
        k = cache_key(key['period'], key['hotel'],key['room'])
        Rails.cache.write(k, key['rate'], expires_in: CACHE_TTL) if key['rate']
      end
    else
      puts 'error'
      errors << attributes_with_rates.body['error']
    end

    puts 'out job'
  end

  private

  def all_keys
    Api::V1::PricingController::VALID_PERIODS.flat_map do |period|
      Api::V1::PricingController::VALID_HOTELS.flat_map do |hotel|
        Api::V1::PricingController::VALID_ROOMS.flat_map do |room|
          [{ period:, hotel:, room: }]
        end
      end
    end
  end

  def cache_key(period, hotel, room)
    "rate|#{period}|#{hotel}|#{room}"
  end
end
