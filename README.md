# Losant Ruby MQTT Client

[![Build Status](https://travis-ci.org/Losant/losant-mqtt-ruby.svg?branch=master)](https://travis-ci.org/Losant/losant-mqtt-ruby) [![Gem Version](https://badge.fury.io/rb/losant_mqtt.svg)](https://badge.fury.io/rb/losant_mqtt)

The [Losant](https://www.losant.com) MQTT client provides a simple way for
custom things to communicate with the Losant platform over MQTT.  You can
authenticate as a device, publish device state, and listen for device commands.

This client works with Ruby 2.1 and higher, and it depends on [Event Machine](https://github.com/eventmachine/eventmachine) to provide
event-driven I/O.

<br/>

## Installation

The latest stable version is available in RubyGems and can be installed using

```bash
gem install losant_mqtt
```

<br/>

## Example

Below is a high-level example of using the Losant Ruby MQTT client to send
the value of a temperature sensor to the Losant platform.

```ruby
require "losant_mqtt"

EventMachine.run do

  # Construct device
  device = LosantMqtt::Device.new(
    device_id: "my-device-id",
    key: "my-app-access-key",
    secret: "my-app-access-secret")

  # Send temperature once every ten seconds.
  EventMachine::PeriodicTimer.new(10.0) do
    temp = call_out_to_your_sensor_here()
    device.send_state({ temperature: temp })
    puts "#{device.device_id}: Sent state"
  end

  # Listen for commands.
  device.on(:command) do |d, command|
    puts "#{d.device_id}: Command received."
    puts command["name"]
    puts command["payload"]
  end

  # Listen for connection event
  device.on(:connect) do |d|
    puts "#{d.device_id}: Connected"
  end

  # Listen for reconnection event
  device.on(:reconnect) do |d|
    puts "#{d.device_id}: Reconnected"
  end

  # Listen for disconnection event
  device.on(:close) do |d, reason|
    puts "#{d.device_id}: Lost connection (#{reason})"
  end

  # Connect to Losant.
  device.connect
end
```

<br/>

## API Documentation

*   [Device](#device)
    *   [initializer](#initializer)
    *   [connect](#connect)
    *   [connected?](#connected)
    *   [close](#close)
    *   [send_state](#send_state)
    *   [on](#on)
    *   [add_listener](#add_listener)
    *   [remove_listener](#remove_listener)

### Device

A device represents a single thing or widget that you'd like to connect to
the Losant platform. A single device can contain many different sensors or
other attached peripherals. Devices can either report state or
respond to commands.

A device's state represents a snapshot of the device at some point in time.
If the device has a temperature sensor, it might report state every few seconds
with the temperature. If a device has a button, it might only report state when
the button is pressed. Devices can report state as often as needed by your
specific application.

Commands instruct a device to take a specific action. Commands are defined as a
name and an optional payload. For example, if the device is a scrolling marquee,
the command might be "update text" and the payload would include the text
to update.

#### initializer

```ruby
LosantMqtt::Device.new(device_id:, key:, secret:, secure: true, retry_lost_connection: true)
```

The ``Client()`` initializer takes the following arguments:

*   device_id  
The device's ID. Obtained by first registering a device using
the Losant platform.

*   key  
The Losant access key.

*   secret  
The Losant access secret.

*   secure  
If the client should connect to Losant over SSL - default is true.

*   retry_lost_connection  
If the client should retry lost connections - default is true.  Errors on
initial connect will still be raised, but if a good connection is
subsequently lost and this flag is true, the client will try to automatically
reconnect and will not raise errors (except in the case of authentication
errors, which will still be raised). When this flag is true, disconnection
and reconnection can be monitored using the `:close` and `:reconnect` events.

###### Example

```ruby
device = LosantMqtt::Device.new(device_id: "my-device-id",
  key: "my-app-access-key", secret: "my-app-access-secret")
```

#### connect

```ruby
connect()
```

Connects the device to the Losant platform. Hook the `:connect` event to know when
a connection has been successfully established.  Returns the device instance
to allow chaining.

#### connected?

```ruby
connected?()
```

Returns a boolean indicating whether or not the device is currently connected
to the Losant platform.

#### close

```ruby
close()
```

Closes the device's connection to the Losant platform.

#### send_state

```ruby
send_state(state, time = nil)
```

Sends a device state to the Losant platform. In many scenarios, device
states will change rapidly. For example a GPS device will report GPS
coordinates once a second or more. Because of this, sendState is typically
the most invoked function. Any state data sent to Losant is stored and made
available in data visualization tools and workflow triggers.

*   state  
The state to send as a hash.

*   time  
When the state occured - if nil or not set, will default to now.

###### Example

```ruby
device.send_state({ voltage: read_analog_in() })
```

#### on

```ruby
on(event, proc=nil, &block)
```

Adds an observer to listen for an event on this device.

*   event  
The event name to listen for.  Possible events are: `:connect` (the device
has connected), `:reconnect` (the device lost its connection and reconnected),
`:close` (the device's connection was closed), and
`:command` (the device has received a command from Losant).

*   proc / &block  
The proc or block to call with the given event fires.  The first
argument for all callbacks will be the device instance.  For `:close` callbacks,
there can be a second argument which is the reason for the closing of the
connection, and for `:command` callbacks the second argument is the command
received.

###### Example

```ruby
device.on(:command) do |device, command|
  puts "Command received."
  puts command["name"]
  puts command["payload"]
end
```

#### add_listener

An alias to [on](#on).

#### remove_listener

```ruby
remove_listener(event, proc)
```

Removes an observer from listening for an event on this device.

*   event  
The event name to stop listening for.  Same events as [on](#on).

*   proc  
The proc that should be removed.

<br/>

*****

Copyright (c) 2017 Losant IoT, Inc

<https://www.losant.com>
