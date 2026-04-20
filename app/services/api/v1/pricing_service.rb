module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      c_key = cache_key(@period, @hotel, @room)

      cached = Rails.cache.read(c_key)
      if cached.present?
        @result = cached
      else
        rate = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
        if rate.success?
          parsed_rate = JSON.parse(rate.body)
          parsed_rate['rates'][0]
          @result = parsed_rate['rates'].detect { |r| r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room }&.dig('rate')
        else
          errors << rate.body['error']
        end
      end
    end

    private

    def cache_key(period, hotel, room)
      "rate|#{period}|#{hotel}|#{room}"
    end
  end
end
