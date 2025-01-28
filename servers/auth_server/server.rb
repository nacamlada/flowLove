

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



Dir.glob('instructions/**/*.rb').each { |file| require file }
Dir.glob('pbs/**/*.rb').each { |file| require file }

# Define the service implementation
class Handler < Authserver::AuthServer::Service
  def get_session(request, _unused_call)
    # Implementation of your gRPC function
    redis = Redis.new
    flow_name = JSON.parse(redis.get(request["Flow"]))
    flow, destination, function, timestamp = request["Flow"].split(":", 4)

    steps = build_steps(flow_name)
    result = run_instructions(steps, request.to_h)
    if result[:success]
      required_keys = flow_name["OutputKeys"]
      payload = result[:success].slice(required_keys)
      Authserver.const_get("#{function}Response").new(payload)
    else
      Authserver.const_get("#{function}Response").new(Status: 422)
    end
  end

  def build_steps(flow)
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