require 'gssapi'

module Thrift
  class SaslClientTransport < FramedTransport
    STATUS_BYTES = 1
    PAYLOAD_LENGTH_BYTES = 4
    NEGOTIATION_STATUS = {
      START:    0x01,
      OK:       0x02,
      BAD:      0x03,
      ERROR:    0x04,
      COMPLETE: 0x05
    }

    def initialize(transport, sasl_params={})
      super(transport)
      @sasl_complete = nil
      @sasl_username = sasl_params.fetch(:username, 'anonymous')
      @sasl_password = sasl_params.fetch(:password, 'anonymous')
      @sasl_mechanism = sasl_params.fetch(:mechanism, 'PLAIN')

      unless ['PLAIN', 'GSSAPI'].include? @sasl_mechanism
        raise "Unknown SASL mechanism: #{@sasl_mechanism}"
      end

      if @sasl_mechanism == 'GSSAPI'
        @sasl_remote_principal = sasl_params[:remote_principal]
        @sasl_remote_host = sasl_params[:remote_host]
        @gsscli = GSSAPI::Simple.new(@sasl_remote_host, @sasl_remote_principal)
      end
    end

    def open
      super

      case @sasl_mechanism
      when 'PLAIN'
        handshake_plain!
      when 'GSSAPI'
        handshake_gssapi!
      end
    end

    private

    def handshake_plain!
      token = "[#{@sasl_mechanism}]\u0000#{@sasl_username}\u0000#{@sasl_password}"
      write_handshake_message(NEGOTIATION_STATUS[:START], @sasl_mechanism)
      write_handshake_message(NEGOTIATION_STATUS[:OK], token)

      status, msg = read_handshake_message
      case status
      when NEGOTIATION_STATUS[:COMPLETE]
        @sasl_complete = true
      when NEGOTIATION_STATUS[:OK]
        raise "Failed to complete challenge exchange: only NONE supported currently"
      end
    end

    def handshake_gssapi!
      token = @gsscli.init_context
      write_handshake_message(NEGOTIATION_STATUS[:START], @sasl_mechanism)
      write_handshake_message(NEGOTIATION_STATUS[:OK], token)

      status, msg = read_handshake_message
      case status
      when NEGOTIATION_STATUS[:COMPLETE]
        raise "Unexpected COMPLETE from server"
      when NEGOTIATION_STATUS[:OK]
        unless @gsscli.init_context(msg)
          raise "GSSAPI: challenge provided by server could not be verified"
        end

        write_handshake_message(NEGOTIATION_STATUS[:OK], "")

        status, msg = read_handshake_message
        case status
        when NEGOTIATION_STATUS[:COMPLETE]
          raise "Unexpected COMPLETE from server"
        when NEGOTIATION_STATUS[:OK]
          unwrapped = @gsscli.unwrap_message(msg)
          rewrapped = @gsscli.wrap_message(unwrapped)

          write_handshake_message(NEGOTIATION_STATUS[:COMPLETE], rewrapped)

          status, msg = read_handshake_message
          case status
          when NEGOTIATION_STATUS[:COMPLETE]
            @sasl_complete = true
          when NEGOTIATION_STATUS[:OK]
            raise "Failed to complete GSS challenge exchange"
          end
        end
      end
    end

    def read_handshake_message
      status, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
      body = @transport.to_io.read(len)
      if [NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]].include?(status)
        raise "Exception from server: #{body}"
      end

      [status, body]
    end

    def write_handshake_message(status, message)
      header = [status, message.length].pack('cl>')
      @transport.write(header + message)
    end
  end

  class SaslClientTransportFactory < BaseTransportFactory
    def get_transport(transport)
      return SaslClientTransport.new(transport)
    end
  end
end
