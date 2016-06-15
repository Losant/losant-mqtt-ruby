module LosantMqtt
  module Utils

    def self.convert_ext_json(value)
      if value.respond_to?(:to_ary)
        value = value.to_ary.map{ |v| convert_ext_json(v) }
      end

      if value.respond_to?(:to_hash)
        value = value.to_hash
        if value.length == 1 && value.has_key?("$date")
          value = ::DateTime.parse(value["$date"])
        elsif value.length == 1 && value.has_key?("$undefined")
          value = nil
        else
          value.each do |k, v|
            value[k] = convert_ext_json(v)
          end
        end
      end

      value
    end

  end
end
