module Flipped
  module SettingsManager
    def read_config(attributes, filename)
      settings = if File.exists? filename
         File.open(filename) { |file| YAML::load(file) }
      else
        {}
      end

      attributes.each_pair do |key, data|
        name, default_value = data
        value = settings.has_key?(key) ? settings[key] : default_value
        if name[0] == '@'
          if name =~ /^(.*)\[(.*)\]$/ # @frog[:cheese]
            name, hash_key = $1, $2
            if hash_key[0] == ':'
              hash_key = hash_key[1..-1].to_sym
            end
            instance_variable_get(name)[hash_key] = value
          else  # @frog
            instance_variable_set(name, value)
          end
        else # frog (method)
          send("#{name}=", value)
        end
      end

      nil
    end

    def write_config(attributes, filename)
      settings = {}
      attributes.each_pair do |key, data|
        name, default_value = data
        settings[key] = if name[0] == '@'
          if name =~ /^(.*)\[(.*)\]$/ # @frog[:cheese]
            name, hash_key = $1, $2
            if hash_key[0] == ':'
              hash_key = hash_key[1..-1].to_sym
            end

            instance_variable_get(name)[hash_key]
          else
            instance_variable_get(name) # @frog
          end
        else
          send(name) # frog (method)
        end
      end

      FileUtils::mkdir_p(File.dirname(filename))
      File.open(filename, 'w') { |file| file.puts(settings.to_yaml) }

      nil
    end
  end
end