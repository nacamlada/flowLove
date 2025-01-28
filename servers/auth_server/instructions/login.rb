module Instructions
  class Login
    include Strum::Service

    def call
      if input[:login] == "admin" && input[:password] == "admin"
        output(status: :success)
      else
        add_error(authentication: :login_or_password_are_incorrect)
      end
    end
  end
end