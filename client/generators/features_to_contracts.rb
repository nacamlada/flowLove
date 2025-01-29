require "yaml"
require "redis"
require "json"
require 'fileutils'

module Generators
  class FeaturesToContracts
    PATH_TO_FEATURES = "../features"
    def call
      servers = ["AuthServer"]
      servers.each do |server_name|
        build_proto(server_name)
      end
      yamls = find_yaml_files(PATH_TO_FEATURES)
    end


    def build_proto(server_name, output_dir = '../contracts')
      # Ensure the output directory exists
      FileUtils.mkdir_p(output_dir)
    
      # Define the proto filename
      proto_filename = File.join(output_dir, "#{server_name.downcase}.proto")
    
      # Build the proto file content
      proto_content = <<~PROTO
        syntax = "proto3";
    
        package #{server_name.downcase};
    
        // Universal request message
        message #{server_name}Request {
          string method_name = 1;        // Method name to call
          bytes payload = 2;             // Serialized request data
        }
    
        // Universal response message
        message #{server_name}Response {
          int32 status_code = 1;         // Processing status (e.g., 200, 400, 500)
          string message = 2;            // Message or error description
          bytes payload = 3;             // Serialized response data
        }
    
        // gRPC service with a single universal method
        service #{server_name}Service {
          rpc HandleRequest (#{server_name}Request) returns (#{server_name}Response);
        }
      PROTO
    
      # Write the content to the proto file
      File.write(proto_filename, proto_content)
      puts "Proto file generated: #{proto_filename}"
    end

    def find_yaml_files(folder_path)
      yaml_files = []
    
      # Отримуємо список всіх файлів і підкаталогів у папці
      Dir.glob("#{PATH_TO_FEATURES}/**/*.{yml,yaml}") do |file|
        if File.file?(file)  # Перевіряємо, чи це файл
          yaml_files << file
        end
      end
    
      generate_logic(yaml_files)
    end

    def read_file_content(file)
      begin
        content = File.read(file)
        puts "\n--- Content of #{file} ---"
        content
      rescue => e
        puts "Error reading file #{file}: #{e.message}"
      end
    end

    # Helper method to convert types from YAML to proto
    def map_type(yaml_type)
      case yaml_type
      when 'String' then 'string'
      when 'Integer' then 'int32'
      when 'Float' then 'float'
      when 'Boolean' then 'bool'
      else
        raise "Unsupported type: #{yaml_type}"
      end
    end

    def generate_logic(files)
      # Load all YAML files from a directory
      output_dir = '../contracts'
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      executors_by_server = {}
      # Iterate over all YAML files in the directory
      files.each do |file|
        yaml_data = YAML.load_file(file)
        server_name = yaml_data.dig('Executor', 'ServerName')
        executor_name = yaml_data.dig('Executor', 'ExecutorName')
        expected_input = yaml_data.dig('Executor', 'ExpectedInput')
        expected_output = yaml_data.dig('Executor', 'ExpectedOutput')
        flow = yaml_data.dig("Flow")
        entry_points = yaml_data["EntryPoints"]
        # Group executors by ServerName
        executors_by_server[server_name] ||= []
        executors_by_server[server_name] << {
          executor_name: executor_name,
          expected_input: expected_input,
          expected_output: expected_output,
          flow: flow,
          entry_points: entry_points
        }
      end

      # Generate .proto files for each server
      executors_by_server.each do |server_name, executors|
        proto_content = <<~PROTO
          syntax = "proto3";

          package #{server_name.downcase};

          service #{server_name} {
        PROTO

        # Add RPC definitions and messages for each executor
        message_definitions = ""
        executors.each do |executor|
          executor_name = executor[:executor_name]
          expected_input = executor[:expected_input]
          expected_output = executor[:expected_output]

          # Add RPC method to service definition
          proto_content += "  rpc #{executor_name} (#{executor_name}Request) returns (#{executor_name}Response);\n"

          # Generate input message
          input_fields = expected_input.map do |field_name, details|
            proto_type = map_type(details['Type'])
            "  #{proto_type} #{field_name} = #{details['Index']};"
          end.join("\n")

          message_definitions += <<~MESSAGE

            message #{executor_name}Request {
            #{input_fields}
            }
          MESSAGE

          # Generate output message
          output_fields = expected_output.map do |field_name, details|
            proto_type = map_type(details['Type'])
            "  #{proto_type} #{field_name} = #{details['Index']};"
          end.join("\n")

          message_definitions += <<~MESSAGE

            message #{executor_name}Response {
            #{output_fields}
            }
          MESSAGE

          key = write_to_storage(server_name, executor[:executor_name], executor[:flow].merge("OutputKeys" => executor[:expected_output].keys))
          executor[:entry_points].each do |entry_point|
            write_entrypoint_to_storage(entry_point["Type"], entry_point["RouteMethod"], entry_point["RoutePath"], key)
          end
        end

        # Finalize proto content
        proto_content += "}\n"
        proto_content += message_definitions

        # Write the proto file
        # output_file = File.join(output_dir, "#{server_name.downcase}.proto")
        # File.write(output_file, proto_content)
        # puts "Generated: #{output_file}"
      end
    end

    def write_to_storage(server, executor, flow)
      redis = Redis.new

      # Define the timestamp
      timestamp = Time.now.to_i

      # Store the flow with the timestamp
      flow_key = "flow:#{server}:#{executor}:#{timestamp}"
      redis.set(flow_key, flow.to_json)
      puts "Added flow `#{flow_key}` to storage with payload `#{flow}`"
      flow_key
    end

    def write_entrypoint_to_storage(type, http_method, http_path, value)
      redis = Redis.new

      # Define the timestamp
      timestamp = Time.now.to_i
      # Store the flow with the timestamp
      key = "#{type}:#{http_method.upcase}/#{http_path}"
      redis.set(key, value)
      puts "Added entry `#{key}` to storage with payload `#{value}`"
    end
  end
end
