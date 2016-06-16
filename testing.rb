$LOAD_PATH.push(File.expand_path("../lib", __FILE__));
require "losant_mqtt"

EventMachine.run do
  device = LosantMqtt::Device.new(
    key: "0bbdc673-77ea-423f-9241-976db4776f8b",
    secret: "191bcd2c2512a770a880460f04f46ccf295c414a44b41742c9f3fe0746245fa8",
    device_id: "57615f0ac035bd0100cb964b")

  EventMachine::PeriodicTimer.new(10.0) do
    temp = 10
    device.send_state({ temperature: temp })
    puts "#{device.device_id}: Sent state"
  end

  device.on(:command) do |d, command|
    puts "#{d.device_id}: Command received."
    puts command["name"]
    puts command["payload"]
  end

  device.on(:connect) do |d|
    puts "#{d.device_id}: Connected"
  end

  device.on(:reconnect) do |d|
    puts "#{d.device_id}: Reconnected"
  end

  device.on(:close) do |d, reason|
    puts "#{d.device_id}: Lost connection (#{reason})"
  end

  device.connect
end
