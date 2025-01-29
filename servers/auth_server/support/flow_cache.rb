class FlowCache
  def initialize
    @redis = Redis.new
    @cache = Concurrent::Map.new # Thread safe cache
  end

  def get_flow(flow_key)
    _marker_type, destination, flow_name, timestamp = flow_key.split(":", 4)
    cached = @cache[flow_name]
    return cached[:data] if cached && cached[:timestamp] == timestamp

    if (flow_data = @redis.get(flow_key))
      parsed_data = JSON.parse(flow_data, symbolize_names: true)
      # Обновляем кеш
      @cache[flow_name] = { timestamp: timestamp, data: parsed_data }
      return parsed_data
    end
    nil
  end
end