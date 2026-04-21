require "test_helper"

class PricingCacheUpdaterJobTest < ActiveJob::TestCase
  test "writes rates to cache for all period/hotel/room combinations" do
    rates = all_combinations.map do |attrs|
      { 'period' => attrs[:period], 'hotel' => attrs[:hotel], 'room' => attrs[:room], 'rate' => '9999' }
    end

    RateApiClient.stub(:post, success_response(rates)) do
      PricingCacheUpdaterJob.perform_now
    end

    assert_equal "9999", Rails.cache.read("rate|Summer|FloatingPointResort|SingletonRoom")
    assert_equal "9999", Rails.cache.read("rate|Winter|RecursionRetreat|RestfulKing")
  end

  test "passes all period/hotel/room combinations to the API" do
    captured_attributes = nil
    mock_response = success_response([])

    RateApiClient.stub(:post, ->(path, options) { captured_attributes = JSON.parse(options[:body])["attributes"]; mock_response }) do
      PricingCacheUpdaterJob.perform_now
    end

    expected_count = Pricing::ValidValues::PERIODS.size *
                     Pricing::ValidValues::HOTELS.size *
                     Pricing::ValidValues::ROOMS.size
    assert_equal expected_count, captured_attributes.size
    assert_includes captured_attributes, { 'period' => "Summer", 'hotel' => "FloatingPointResort", 'room' => "SingletonRoom" }
  end

  test "does not overwrite existing cache value when rate is nil" do
    Rails.cache.write("rate|Summer|FloatingPointResort|SingletonRoom", "15000")

    rates = [{ 'period' => 'Summer', 'hotel' => 'FloatingPointResort', 'room' => 'SingletonRoom', 'rate' => nil }]

    RateApiClient.stub(:post, success_response(rates)) do
      PricingCacheUpdaterJob.perform_now
    end

    assert_equal "15000", Rails.cache.read("rate|Summer|FloatingPointResort|SingletonRoom")
  end

  test "re-enqueues job on error" do
    RateApiClient.stub(:post, ->(*) { raise StandardError, "something failed" }) do
      assert_enqueued_with(job: PricingCacheUpdaterJob) do
        PricingCacheUpdaterJob.perform_now
      end
    end
  end

  private

  def all_combinations
    Pricing::ValidValues::PERIODS.flat_map do |period|
      Pricing::ValidValues::HOTELS.flat_map do |hotel|
        Pricing::ValidValues::ROOMS.map { |room| { period: period, hotel: hotel, room: room } }
      end
    end
  end

  def success_response(rates)
    OpenStruct.new(success?: true, body: { 'rates' => rates }.to_json)
  end
end
