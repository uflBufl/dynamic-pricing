class PricingCacheUpdaterJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    Rails.logger.tagged(self.class.name, "job_id=#{job_id}") do
      start_time = Time.current
      Rails.logger.info("started")

      response = RateApiClient.get_rates(all_keys)
      raise HTTParty::Error, response.body.to_s unless response.success?

      write_rates_to_cache(JSON.parse(response.body)["rates"])

      Rails.logger.info({event: "finish", duration: (Time.current - start_time)}.to_json)
    end
  rescue => e
    Rails.logger.error({ event: "error", error: e.message }.to_json)
    raise
  end

  private

  def write_rates_to_cache(rates)
    rates.each do |rate|
      next unless rate['rate']

      Rails.cache.write(
        Pricing::ValidValues.cache_key(rate['period'], rate['hotel'], rate['room']),
        rate['rate'],
        expires_in: Pricing::ValidValues::CACHE_TTL
      )
    end
  end

  def all_keys
    Pricing::ValidValues::PERIODS.flat_map do |period|
      Pricing::ValidValues::HOTELS.flat_map do |hotel|
        Pricing::ValidValues::ROOMS.map { |room| { period: period, hotel: hotel, room: room } }
      end
    end
  end
end
