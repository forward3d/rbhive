require 'gssapi'

module Thrift
  class SaslClientTransport < BufferedTransport
    attr_reader :sasl_complete

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
      raise 'Unknown SASL mechanism: #{@sasl_mechanism}' unless ['PLAIN', 'GSSAPI'].include? @sasl_mechanism
      if @sasl_mechanism == 'GSSAPI'
        @sasl_remote_principal = sasl_params[:remote_principal]
        @sasl_remote_host = sasl_params[:remote_host]
        @gsscli = GSSAPI::Simple.new(@sasl_remote_host, @sasl_remote_principal)
      end
    end

    def read(sz)
      len, = @transport.read(PAYLOAD_LENGTH_BYTES).unpack('l>') if @rbuf.nil?
      sz = len if len && sz > len
      @index += sz
      ret = @rbuf.slice(@index - sz, sz) || Bytes.empty_byte_buffer
      if ret.length == 0
        @rbuf = @transport.read(len) rescue Bytes.empty_byte_buffer
        @index = sz
        ret = @rbuf.slice(0, sz) || Bytes.empty_byte_buffer
      end
      ret
    end

    def read_byte
      reset_buffer! if @index >= @rbuf.size
      @index += 1
      Bytes.get_string_byte(@rbuf, @index - 1)
    end

    def read_into_buffer(buffer, size)
      i = 0
      while i < size
        reset_buffer! if @index >= @rbuf.size
        byte = Bytes.get_string_byte(@rbuf, @index)
        Bytes.set_string_byte(buffer, i, byte)
        @index += 1
        i += 1
      end
      i
    end

    def write(buf)
      unless @sasl_complete
        case @sasl_mechanism
        when 'PLAIN'
          initiate_hand_shake_plain
        when 'GSSAPI'
          initiate_hand_shake_gssapi
        end
      end
      header = [buf.length].pack('l>')
      @wbuf << (header + Bytes.force_binary_encoding(buf))
    end

    protected

    def initiate_hand_shake_gssapi
      token = @gsscli.init_context
      header = [NEGOTIATION_STATUS[:START], @sasl_mechanism.length].pack('cl>')
      @transport.write header + @sasl_mechanism
      header = [NEGOTIATION_STATUS[:OK], token.length].pack('cl>')
      @transport.write header + token
      status, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
      case status
      when NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]
        raise @transport.to_io.read(len)
      when NEGOTIATION_STATUS[:COMPLETE]
        raise "Not expecting COMPLETE at initial stage"
      when NEGOTIATION_STATUS[:OK]
        challenge = @transport.to_io.read len
        unless @gsscli.init_context(challenge)
          raise "GSSAPI: challenge provided by server could not be verified"
        end
        header = [NEGOTIATION_STATUS[:OK], 0].pack('cl>')
        @transport.write header
        status2, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
        case status2
        when NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]
          raise @transport.to_io.read(len)
        when NEGOTIATION_STATUS[:COMPLETE]
          raise "Not expecting COMPLETE at second stage"
        when NEGOTIATION_STATUS[:OK]
          challenge = @transport.to_io.read len
          unwrapped = @gsscli.unwrap_message(challenge)
          rewrapped = @gsscli.wrap_message(unwrapped)
          header = [NEGOTIATION_STATUS[:COMPLETE], rewrapped.length].pack('cl>')
          @transport.write header + rewrapped
          status3, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
          case status3
          when NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]
            raise @transport.to_io.read(len)
          when NEGOTIATION_STATUS[:COMPLETE]
            @transport.to_io.read len
            @sasl_complete = true
          when NEGOTIATION_STATUS[:OK]
            raise "Failed to complete GSS challenge exchange"
          end
        end
      end
    end

    def initiate_hand_shake_plain
      header = [NEGOTIATION_STATUS[:START], @sasl_mechanism.length].pack('cl>')
      @transport.write header + @sasl_mechanism
      message = "[#{@sasl_mechanism}]\u0000#{@sasl_username}\u0000#{@sasl_password}"
      header = [NEGOTIATION_STATUS[:OK], message.length].pack('cl>')
      @transport.write header + message
      status, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
      case status
      when NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]
        raise @transport.to_io.read(len)
      when NEGOTIATION_STATUS[:COMPLETE]
        @transport.to_io.read len
        @sasl_complete = true
      when NEGOTIATION_STATUS[:OK]
        raise "Failed to complete challenge exchange: only NONE supported currently"
      end
    end

    private

    def reset_buffer!
      len, = @transport.read(PAYLOAD_LENGTH_BYTES).unpack('l>')
      @rbuf = @transport.read(len)
      while @rbuf.size < len
        @rbuf << @transport.read(len - @rbuf.size)
      end
      @index = 0
    end
  end

  class SaslClientTransportFactory < BaseTransportFactory
    def get_transport(transport)
      return SaslClientTransport.new(transport)
    end
  end

end
