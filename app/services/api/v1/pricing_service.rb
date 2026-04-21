module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      Rails.logger.tagged("PricingService") do
        Rails.logger.info({event: "call_started", period: @period, hotel: @hotel, room: @room }.to_json)

        @result = fetch_value
      rescue => e
        Rails.logger.error({ event: "error", error: e.message }.to_json)
        errors << e.message
        nil
      ensure
        Rails.logger.info("call_finished")
      end
    end

    private

    def fetch_value
      value = Rails.cache.read(cache_key)
      return value if value.present?

      fetch_from_api
    end

    def fetch_from_api
      response = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      if response.success?
        rates = JSON.parse(response.body)["rates"]
        rate = rates.detect { |r| r["period"] == @period && r["hotel"] == @hotel && r["room"] == @room }
        value = rate&.dig("rate")

        Rails.cache.write(cache_key, value, expires_in: Pricing::ValidValues::CACHE_TTL) if value
        value
      else
        errors << JSON.parse(response.body)["error"]
        nil
      end
    end

    def cache_key
      @cache_key ||= Pricing::ValidValues.cache_key(@period, @hotel, @room)
    end
  end
end