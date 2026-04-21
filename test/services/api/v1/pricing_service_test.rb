require "test_helper"

class ApiV1PricingServiceTest < ActiveSupport::TestCase
  PERIOD = "Summer"
  HOTEL  = "FloatingPointResort"
  ROOM   = "SingletonRoom"

  test "returns cached rate without calling the API" do
    Rails.cache.write("rate|#{PERIOD}|#{HOTEL}|#{ROOM}", "15000")

    RateApiClient.stub(:get_rate, ->(*) { flunk "API should not be called on cache hit" }) do
      result = Api::V1::PricingService.new(period: PERIOD, hotel: HOTEL, room: ROOM).run

      assert_equal "15000", result
    end
  end

  test "fetches rate from API on cache miss" do
    mock_response = success_response([{ 'period' => PERIOD, 'hotel' => HOTEL, 'room' => ROOM, 'rate' => '12000' }])

    RateApiClient.stub(:get_rate, mock_response) do
      service = Api::V1::PricingService.new(period: PERIOD, hotel: HOTEL, room: ROOM)
      result = service.run

      assert service.valid?
      assert_equal "12000", result
    end
  end

  test "returns nil when API response contains no matching rate" do
    mock_response = success_response([])

    RateApiClient.stub(:get_rate, mock_response) do
      service = Api::V1::PricingService.new(period: PERIOD, hotel: HOTEL, room: ROOM)
      result = service.run

      assert service.valid?
      assert_nil result
    end
  end

  test "is invalid and adds error when API returns failure" do
    mock_response = OpenStruct.new(success?: false, body: { 'error' => 'Service unavailable' }.to_json)

    RateApiClient.stub(:get_rate, mock_response) do
      service = Api::V1::PricingService.new(period: PERIOD, hotel: HOTEL, room: ROOM)
      service.run

      refute service.valid?
      assert_includes service.errors, "Service unavailable"
    end
  end

  private

  def success_response(rates)
    OpenStruct.new(success?: true, body: { 'rates' => rates }.to_json)
  end
end