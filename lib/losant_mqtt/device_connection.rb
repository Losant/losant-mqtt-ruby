module LosantMqtt
  CA_FILE_PATH = File.expand_path(File.join(File.dirname(__FILE__), "RootCA.crt"))

  class DeviceConnection < EventMachine::Connection
    include Events::Emitter

    attr_reader :state

    def self.connect(options = {})
      options = { host: "localhost", port: MQTT::DEFAULT_PORT }.merge(options)
      EventMachine.connect(options[:host], options[:port], self, options)
    end

    def initialize(options = {})
      @options = {
        client_id:     MQTT::Client.generate_client_id,
        keep_alive:    15,
        clean_session: true,
        username:      nil,
        password:      nil,
        version:       "3.1.1"
      }.merge(options)
      @subscriptions = {}
    end

    def connected?
      state == :connected
    end

    def publish(topic, payload)
      send_packet(MQTT::Packet::Publish.new(
        id:      next_packet_id,
        qos:     0,
        retain:  false,
        topic:   topic,
        payload: payload))
    end

    def subscribe(topic, &block)
      @subscriptions[topic] = block
      send_packet(MQTT::Packet::Subscribe.new(id: next_packet_id, topics: [topic]))
    end

    def unsubscribe(topic)
      @subscriptions.delete(topic)
      send_packet(MQTT::Packet::Unsubscribe.new(id: next_packet_id, topics: [topic]))
    end

    def disconnect(send_msg: true)
      return if @state == :disconnecting || @state == :disconnected
      @state = :disconnecting
      emit(@state)
      send_packet(MQTT::Packet::Disconnect.new) if connected? && send_msg
    end

    def send_connect_packet
      packet = MQTT::Packet::Connect.new(
        client_id:     @options[:client_id],
        clean_session: @options[:clean_session],
        keep_alive:    @options[:keep_alive],
        username:      @options[:username],
        password:      @options[:password],
        version:       @options[:version])
      send_packet(packet)
      @state = :connect_sent
      emit(@state)
    end

    def process_packet(packet)
      @last_received = Time.now.to_i
      if state == :connect_sent && packet.class == MQTT::Packet::Connack
        connect_ack(packet)
      elsif state == :connected && packet.class == MQTT::Packet::Pingresp
        # Pong!
      elsif state == :connected && packet.class == MQTT::Packet::Publish
        @subscriptions[packet.topic].call(packet.payload) if @subscriptions[packet.topic]
      elsif state == :connected && packet.class == MQTT::Packet::Puback
        # publish acked
      elsif state == :connected && packet.class == MQTT::Packet::Suback
        # Subscribed!
      elsif state == :connected && packet.class == MQTT::Packet::Unsuback
        # Unsubscribed!
      else
        # CONNECT only sent by client
        # SUBSCRIBE only sent by client
        # PINGREQ only sent by client
        # UNSUBSCRIBE only sent by client
        # DISCONNECT only sent by client
        # PUBREC/PUBREL/PUBCOMP for QOS2 - do not support
        @ex = MQTT::ProtocolException.new("Wasn't expecting packet of type #{packet.class} when in state #{state}")
        close_connection
      end
    end

    def connect_ack(packet)
      if packet.return_code != 0x00
        @ex = MQTT::ProtocolException.new("Authentication Error - " + packet.return_msg)
        return close_connection
      end

      @state = :connected

      if @options[:keep_alive] > 0
        @timer = EventMachine::PeriodicTimer.new(@options[:keep_alive]) do
          if(Time.now.to_i - @last_received > @options[:keep_alive])
            @ex = MQTT::NotConnectedException.new("Keep alive failure, disconnecting")
            close_connection
          else
            send_packet(MQTT::Packet::Pingreq.new)
          end
        end
      end

      emit(@state)
    end

    def next_packet_id
      @packet_id += 1
    end

    def send_packet(packet)
      send_data(packet.to_s)
    end

    def unbind(msg)
      @timer.cancel if @timer
      unless @state == :disconnecting
        @ex ||= $! || MQTT::NotConnectedException.new("Connection to server lost")
      end

      @state = :disconnected
      emit(@state, @ex)
    end

    def receive_data(data)
      @data << data

      # Are we at the start of a new packet?
      if !@packet && @data.length >= 2
        @packet = MQTT::Packet.parse_header(@data)
      end

      # Do we have the the full packet body now?
      if @packet && @data.length >= @packet.body_length
        @packet.parse_body(@data.slice!(0...@packet.body_length))
        process_packet(@packet)
        @packet = nil
        receive_data("")
      end
    end

    def post_init
      @state         = :connecting
      @last_received = 0
      @packet_id     = 0
      @packet        = nil
      @data          = ""
      emit(@state)
    end

    def connection_completed
      if @options[:secure]
        @last_seen_cert    = nil
        @certificate_store = OpenSSL::X509::Store.new
        @certificate_store.add_file(CA_FILE_PATH)
        start_tls(:verify_peer => true)
      else
        send_connect_packet
      end
    end

    def ssl_verify_peer(cert_string)
      @last_seen_cert = OpenSSL::X509::Certificate.new(cert_string)
      unless @certificate_store.verify(@last_seen_cert)
        @ex = OpenSSL::OpenSSLError.new("Unable to verify the certificate for #{@options[:host]}")
        return false
      end

      begin
        @certificate_store.add_cert(@last_seen_cert)
      rescue OpenSSL::X509::StoreError => e
        unless e.message == "cert already in hash table"
          @ex = e
          return false
        end
      end

      true
    end

    def ssl_handshake_completed
      unless OpenSSL::SSL.verify_certificate_identity(@last_seen_cert, @options[:host])
        @ex = OpenSSL::OpenSSLError.new("The hostname #{@options[:host]} does not match the server certificate")
        return close_connection
      end

      send_connect_packet
    end

  end
end
