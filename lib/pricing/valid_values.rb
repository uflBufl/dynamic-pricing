# frozen_string_literal: true
module Pricing
  module ValidValues
    PERIODS = %w[Summer Autumn Winter Spring].freeze
    HOTELS  = %w[FloatingPointResort GitawayHotel RecursionRetreat].freeze
    ROOMS   = %w[SingletonRoom BooleanTwin RestfulKing].freeze
    CACHE_TTL = 5.minutes

    def self.cache_key(period, hotel, room)
      "rate|#{period}|#{hotel}|#{room}"
    end
  end
end