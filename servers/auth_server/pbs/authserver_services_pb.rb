# Generated by the protocol buffer compiler.  DO NOT EDIT!
# Source: authserver.proto for package 'authserver'

require 'grpc'
require 'authserver_pb'

module Authserver
  module AuthServerService
    # gRPC service with a single universal method
    class Service

      include ::GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'authserver.AuthServerService'

      rpc :HandleRequest, ::Authserver::AuthServerRequest, ::Authserver::AuthServerResponse
    end

    Stub = Service.rpc_stub_class
  end
end
