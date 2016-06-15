require "openssl"
require "date"
require "json"

require "mqtt"
require "eventmachine"
require "events"

require_relative "losant_mqtt/version"
require_relative "losant_mqtt/utils"
require_relative "losant_mqtt/device_connection"
require_relative "losant_mqtt/device"

module LosantMqtt
  COMMAND_TOPIC    = "losant/%{device_id}/command"
  STATE_TOPIC      = "losant/%{device_id}/state"
  DEFAULT_ENDPOINT = "broker.losant.com"

  def self.endpoint
    @endpoint || DEFAULT_ENDPOINT
  end

  def self.endpoint=(domain)
    @endpoint = domain
  end
end
