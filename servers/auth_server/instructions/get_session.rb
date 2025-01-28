module Instructions
  class GetSession
    include Strum::Service

    def call
      output(session_id: rand(1..99999999999), language: "en", account_id: 1)
    end
  end
end