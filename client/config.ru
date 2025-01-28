# cat config.ru
$LOAD_PATH.unshift(
  File.expand_path(".", __dir__),
  File.expand_path("./pbs", __dir__),
  # File.expand_path("./entity", __dir__),
  # File.expand_path("./services", __dir__),
)
require "byebug"

require "generators/features_to_contracts"
Generators::FeaturesToContracts.new.call
Dir.glob('../contracts/**/*.proto').each do |file|
  next unless File.file?(file)
  system("grpc_tools_ruby_protoc -I ../contracts --ruby_out=./pbs --grpc_out=./pbs #{file}")
end

Dir.glob('pbs/**/*.rb').each { |file| require file }

require "roda"
require "yaml"
require "erb"
require "byebug"
require 'grpc'
require "config/initializers/servers"

class App < Roda
  plugin :middleware
  plugin :json, content_type: "application/vnd.api+json"

  # $config = YAML.safe_load(ERB.new(File.read('../features/login/login.yml')).result)

  route do |r|
    instruction = get_route_instruction(r)
    if instruction
      flow_, destination, function, timestamp = instruction.split(":", 4)
      client = Configuration::Servers.public_send(destination)

      # TODO: make it dynamically
      stub = Authserver::AuthServer::Stub.new("#{client[:host]}:#{client[:port]}", client[:secure_flag])
  
      # Виклик gRPC функції
      req = Authserver.const_get("#{function}Request").new(r.params.merge(Flow: instruction))
      res = stub.public_send(underscore(function), req)
      "Response from gRPC: #{JSON.parse(res.to_json)}"
      response.status = res["session_id"]
      "OK"
    else
      response.status = 404
      nil
    end

    # Зчитування маршрутів з кількох YAML файлів
    # r.is("session", method: :get) do
    #   client = Configuration::Servers.public_send("AuthServer")
    #   stub = Authserver::AuthServer::Stub.new("#{client[:host]}:#{client[:port]}", client[:secure_flag])

    #   # Виклик gRPC функції
    #   byebug
    #   req = Authserver::GetSessionRequest.new(r.params)
    #   res = stub.get_session(req)
    #   "Response from gRPC: #{JSON.parse(res.to_json)}"
    #   response.status = res["Status"]
    #   "OK"
    # end
    # load_routes_from_yaml { |route| define_route(r, route) }
  end

  private

  # Метод для завантаження рутів з YAML файлу
  def load_routes_from_yaml
    routes = $config["interfaces"]
    routes.each do |route|
      yield route
    end
  end

  def underscore(str)
    str
      .gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr("-", "_")
      .downcase
  end

  def get_route_instruction(r)
    redis = Redis.new
    redis.get("Route:#{r.request_method}#{r.path}")
  end

  # Метод для визначення роута в Roda
  def define_route(r, route)
    r.public_send(route['method'].downcase, route['route']) do
      # Динамічно завантажуємо клас обробника
      # Налаштування клієнта
      client = Configuration::Servers.public_send(route["server"])
      stub = Example::ExampleService::Stub.new("#{client[:host]}:#{client[:port]}", client[:secure_flag])

      # Виклик gRPC функції
      request = Example::YourRequest.new(param: 'world')
      response = stub.your_function(request)
      
      "Response from gRPC: #{response.result}"
      response.result
    end
  end
end

run App.freeze.app