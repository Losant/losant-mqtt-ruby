require "losant_mqtt"

describe LosantMqtt::Device do

  it "raises error on missing required initializer args" do
    expect do
      LosantMqtt::Device.new(key: "key", secret: "secret")
    end.to raise_error(ArgumentError)

    expect do
      LosantMqtt::Device.new(device_id: "device_id", secret: "secret")
    end.to raise_error(ArgumentError)

    expect do
      LosantMqtt::Device.new(device_id: "device_id", key: "key")
    end.to raise_error(ArgumentError)
  end

  it "should correctly connect, send state, and receive a command" do
    EventMachine.run do
      EventMachine.add_timer(15) { raise RuntimeError.new("Test Timed Out") }

      # associated with app id 57615eebc035bd0100cb964a
      # workflow that takes state reported and sends a command back
      device = LosantMqtt::Device.new(
        device_id: ENV["DEVICE_ID"] || "57615f0ac035bd0100cb964b",
        key: ENV["LOSANT_KEY"] || "0bbdc673-77ea-423f-9241-976db4776f8b",
        secret: ENV["LOSANT_SECRET"])
      expect(device.connected?).to eq(false)

      callbacks_called = []

      device.on(:command) do |d, cmd|
        expect(d.connected?).to eq(true)
        callbacks_called.push(:command)
        expect(cmd["name"]).to eq("triggeredCommand")
        expect(cmd["payload"]).to eq({ "result" => "one-1-false" })
        EventMachine.add_timer(0.1) do
          d.close
        end
      end

      device.on(:connect) do |d|
        expect(d.connected?).to eq(true)
        callbacks_called.push(:connect)
      end

      device.on(:reconnect) do
        callbacks_called.push(:reconnect)
      end

      device.on(:close) do |d, reason|
        expect(d.connected?).to eq(false)
        expect(reason).to eq(nil)
        expect(callbacks_called).to eq([:connect, :command])
        EventMachine.add_timer(0.1) do
          EventMachine.stop_event_loop
        end
      end

      device.send_state({ str_attr: "one", num_attr: 1, bool_attr: false })
    end
  end

  it "should reconnect when connection is abnormally lost and flag is true" do
    EventMachine.run do
      EventMachine.add_timer(15) { raise RuntimeError.new("Test Timed Out") }

      # associated with app id 57615eebc035bd0100cb964a
      # workflow that takes state reported and sends a command back
      device = LosantMqtt::Device.new(
        device_id: ENV["DEVICE_ID"] || "57615f0ac035bd0100cb964b",
        key: ENV["LOSANT_KEY"] || "0bbdc673-77ea-423f-9241-976db4776f8b",
        secret: ENV["LOSANT_SECRET"])
      expect(device.connected?).to eq(false)

      callbacks_called = []

      device.on(:command) do |d, cmd|
        expect(d.connected?).to eq(true)
        callbacks_called.push(:command)
        expect(cmd["name"]).to eq("triggeredCommand")
        expect(cmd["payload"]).to eq({ "result" => "two-2-true" })
        EventMachine.add_timer(0.1) do
          d.close
        end
      end

      device.on(:connect) do |d|
        expect(d.connected?).to eq(true)
        callbacks_called.push(:connect)
        EventMachine.add_timer(0.1) do
          # abnormally force close underlying socket
          d.instance_variable_get("@connection").close_connection
        end
      end

      device.on(:reconnect) do |d|
        expect(d.connected?).to eq(true)
        callbacks_called.push(:reconnect)
        d.send_state({ str_attr: "two", num_attr: 2, bool_attr: true })
      end

      close_count = 0
      device.on(:close) do |d, reason|
        expect(d.connected?).to eq(false)
        callbacks_called.push(:close)
        close_count += 1
        if close_count == 1
          expect(callbacks_called).to eq([:connect, :close])
          expect(reason.message).to eq("Connection to server lost")
        else
          expect(reason).to eq(nil)
          expect(callbacks_called).to eq([:connect, :close, :reconnect, :command, :close])
          EventMachine.add_timer(0.1) do
            EventMachine.stop_event_loop
          end
        end
      end

      device.connect
    end
  end

  it "should not reconnect when connection is abnormally lost and flag is false" do
    expect do
      EventMachine.run do
        EventMachine.add_timer(15) { raise RuntimeError.new("Test Timed Out") }

        # associated with app id 57615eebc035bd0100cb964a
        # workflow that takes state reported and sends a command back
        device = LosantMqtt::Device.new(
          device_id: ENV["DEVICE_ID"] || "57615f0ac035bd0100cb964b",
          key: ENV["LOSANT_KEY"] || "0bbdc673-77ea-423f-9241-976db4776f8b",
          secret: ENV["LOSANT_SECRET"],
          retry_lost_connection: false)
        expect(device.connected?).to eq(false)

        callbacks_called = []

        device.on(:reconnect) do
          callbacks_called.push(:reconnect)
        end

        device.on(:command) do
          callbacks_called.push(:command)
        end

        device.on(:connect) do |d|
          expect(d.connected?).to eq(true)
          callbacks_called.push(:connect)
          EventMachine.add_timer(0.1) do
            # abnormally force close underlying socket
            d.instance_variable_get("@connection").close_connection
          end
        end

        device.on(:close) do |d, reason|
          expect(d.connected?).to eq(false)
          callbacks_called.push(:close)
          expect(callbacks_called).to eq([:connect, :close])
          expect(reason.message).to eq("Connection to server lost")
        end

        device.connect
      end
    end.to raise_error(MQTT::NotConnectedException)
  end

  it "should raise errors on initial bad connect" do
    expect do
      EventMachine.run do
        EventMachine.add_timer(15) { raise RuntimeError.new("Test Timed Out") }
        device = LosantMqtt::Device.new(
          device_id: "not a device id",
          key: "not a key",
          secret: "not a secret")

        callbacks_called = []

        device.on(:reconnect) do
          callbacks_called.push(:reconnect)
        end

        device.on(:command) do
          callbacks_called.push(:command)
        end

        device.on(:connect) do
          callbacks_called.push(:connect)
        end

        device.on(:close) do |d, reason|
          expect(d.connected?).to eq(false)
          callbacks_called.push(:close)
          expect(callbacks_called).to eq([:close])
          expect(reason.message).to eq("Authentication Error - Connection refused: not authorised")
        end

        device.connect
      end
    end.to raise_error(MQTT::ProtocolException)
  end

end
