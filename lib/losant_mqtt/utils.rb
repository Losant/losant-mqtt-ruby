# The MIT License (MIT)
#
# Copyright (c) 2021 Losant IoT, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
