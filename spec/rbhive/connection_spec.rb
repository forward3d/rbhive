require 'rbhive/connection'

describe RBHive do
  describe '.connect' do

    # Mock any attempts to open a socket
    let(:socket) { double('Thrift::Socket').as_null_object }
    before do
      allow(Thrift::Socket).to receive(:new).and_return(socket)
    end

    let(:server) { 'localhost' }
    let(:port) { 10_000 }

    it 'yields the connection to the block' do
      expect(@connection).to be(nil)
      RBHive.connect(server, port) do |connection|
        @connection = connection
      end
      expect(@connection.class).to be(RBHive::Connection)
    end
  end
end
