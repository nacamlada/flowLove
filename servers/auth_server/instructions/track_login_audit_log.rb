module Instructions
  class TrackLoginAuditLog
    include Strum::Service

    def call
      puts "Logged in by LOGIN -> #{input[:login]} AND PASSWORD: #{input[:password]}"
    end
  end
end