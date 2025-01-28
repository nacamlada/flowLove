module Configuration
  class Servers
    def self.AuthServer
      {
        host: "0.0.0.0",
        port: "50051",
        secure_flag: :this_channel_is_insecure
      }
    end
  end
end