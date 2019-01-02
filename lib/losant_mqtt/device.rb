# The MIT License (MIT)
#
# Copyright (c) 2019 Losant IoT, Inc.
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
  class Device
    include Events::Emitter

    attr_reader :device_id, :key, :secret, :secure, :should_retry

    def initialize(options = {})
      @was_connected = false

      @device_id     = options[:device_id].to_s
      @key           = options[:key].to_s
      @secret        = options[:secret].to_s
      @secure        = options.has_key?(:secure) ? !!options[:secure] : true
      @should_retry  = options.has_key?(:retry_lost_connection) ?
        !!options[:retry_lost_connection] : true

      raise ArgumentError.new("Invalid Device Id") if @device_id == ""
      raise ArgumentError.new("Invalid Key") if @key == ""
      raise ArgumentError.new("Invalid Secret") if @secret == ""
    end

    def connected?
      !!(@connection && @connection.connected?)
    end

    def connect
      return self if @retry_timer || @connection

      begin
        @connection = DeviceConnection.connect(
          host:      LosantMqtt.endpoint,
          port:      @secure ? 8883 : 1883,
          secure:    @secure,
          username:  @key,
          password:  @secret,
          client_id: @device_id)
      rescue Exception => ex
        if @was_connected && @should_retry
          @connection = nil
          emit(:close, self, ex)
          retry_lost_connection
          return self
        else
          raise ex
        end
      end

      @connection.on(:disconnected) do |reason|
        @connection = nil
        emit(:close, self, reason)

        if reason
          if @was_connected && @should_retry && !(reason.message =~ /Authentication Error/)
            # if it was not an authentication error
            # and we ave successfully connected before
            # attempt to reconnect in a few seconds
            retry_lost_connection
          else
            raise reason
          end
        end
      end

      @connection.on(:connected) do
        if(@state_backlog)
          @connection.publish(state_topic, @state_backlog.to_json)
          @state_backlog = nil
        end

        if @was_connected
          emit(:reconnect, self)
        else
          @was_connected = true
          emit(:connect, self)
        end

        @connection.subscribe(command_topic) do |msg|
          begin
            msg = Utils.convert_ext_json(JSON.parse(msg))
          rescue JSON::ParserError
            msg = nil
          end
          emit(:command, self, msg) if msg
        end
      end

      self
    end

    def close
      @connection.disconnect if @connection
      if @retry_timer
        @retry_timer.cancel
        @retry_timer = nil
      end
      true
    end

    def send_state(state, time = nil)
      connect unless @connection

      time ||= Time.now
      time = time.to_time if time.respond_to?(:to_time)
      time = time.to_f
      time = time * 1000 if time < 1000000000000 # convert to ms since epoch
      time = time.round

      payload = { time: time, data: state }

      if connected?
        @connection.publish(state_topic, payload.to_json)
      else
        (@state_backlog ||= []).push(payload)
      end

      true
    end

    def retry_lost_connection(wait=5)
      return false if @connection
      @retry_timer ||= EventMachine::Timer.new(wait) do
        @retry_timer = nil
        connect
      end
    end

    def state_topic
      @state_topic ||= LosantMqtt::STATE_TOPIC % { device_id: @device_id }
    end

    def command_topic
      @command_topic ||= LosantMqtt::COMMAND_TOPIC % { device_id: @device_id }
    end
  end
end
