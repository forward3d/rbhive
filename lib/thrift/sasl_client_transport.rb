module Thrift
  class SaslClientTransport < BufferedTransport
    attr_reader :challenge

    STATUS_BYTES = 1
    PAYLOAD_LENGTH_BYTES = 4
    AUTH_MECHANISM = 'PLAIN'
    NEGOTIATION_STATUS = {
      START:    0x01,
      OK:       0x02,
      BAD:      0x03,
      ERROR:    0x04,
      COMPLETE: 0x05
    }

    def initialize(transport, sasl_params={})
      super(transport)
      @challenge = nil
      @sasl_username = sasl_params.fetch(:username, 'anonymous')
      @sasl_password = sasl_params.fetch(:password, 'anonymous')
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
      initiate_hand_shake if @challenge.nil?
      header = [buf.length].pack('l>')
      @wbuf << (header + Bytes.force_binary_encoding(buf))
    end

    protected

    def initiate_hand_shake
      header = [NEGOTIATION_STATUS[:START], AUTH_MECHANISM.length].pack('cl>')
      @transport.write header + AUTH_MECHANISM
      message = "[#{AUTH_MECHANISM}]\u0000#{@sasl_username}\u0000#{@sasl_password}"
      header = [NEGOTIATION_STATUS[:OK], message.length].pack('cl>')
      @transport.write header + message
      status, len = @transport.read(STATUS_BYTES + PAYLOAD_LENGTH_BYTES).unpack('cl>')
      case status
      when NEGOTIATION_STATUS[:BAD], NEGOTIATION_STATUS[:ERROR]
        raise @transport.to_io.read(len)
      when NEGOTIATION_STATUS[:COMPLETE]
        @challenge = ""
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
