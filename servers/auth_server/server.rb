# service.rb
$LOAD_PATH.unshift(
  File.expand_path(".", __dir__),
  File.expand_path("./pbs", __dir__),
  # File.expand_path("./entity", __dir__),
  # File.expand_path("./services", __dir__),
)
require "byebug"

Dir.glob('../../contracts/**/*.proto').each do |file|
  next unless File.file?(file)
  system("grpc_tools_ruby_protoc -I ../../contracts --ruby_out=./pbs --grpc_out=./pbs #{file}")
end

require 'grpc'
require "strum/service"
require "strum/pipe"
require "strum/json"
require "redis"
require "concurrent"

Dir.glob('instructions/**/*.rb').each { |file| require file }
Dir.glob('pbs/**/*.rb').each { |file| require file }
Dir.glob('support/**/*.rb').each { |file| require file }

# Define the service implementation
inherited_klass = Authserver::AuthServerService::Service
class Handler < inherited_klass
  def initialize
    @cache = FlowCache.new
  end

  REDIS = Redis.new
  def handle_request(request, _unused_call)
    # Implementation of your gRPC function
    steps = build_steps(request["method_name"])
    payload = JSON.parse(request["payload"])
    result = run_instructions(steps, payload)
    if result[:success]
      response_payload = { status_code: 200, payload: result[:success].to_json.encode('ASCII-8BIT'), message: "OK" }
      Authserver.const_get("AuthServerResponse").new(response_payload)
    else
      response_payload = { status_code: 422, payload: result[:failure].to_json.encode('ASCII-8BIT'), message: "NOT_OK" }
      Authserver.const_get("AuthServerResponse").new(response_payload)
    end
  end

  def build_steps(flow)
    @cache.get_flow(flow)
    flow = JSON.parse(REDIS.get(flow))
    flow["Steps"].map { |step| Instructions.const_get(step["name"])}
  end

  def run_instructions(steps, input)
    Strum::Pipe.call(*steps, input: input) do |m|
      m.success { |result| { success: result } }
      m.failure { |errors| { failure: errors } }
    end
  end

end

# Start the gRPC server
server = GRPC::RpcServer.new
server.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
server.handle(Handler)
puts "gRPC server running on port 50051..."
server.run_till_terminated