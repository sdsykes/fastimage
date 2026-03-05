# frozen_string_literal: true
require 'socket'

# A raw TCP server that sends an image immediately, then drip-feeds
# padding bytes with long delays. Used to verify that FastImage reads
# only the minimum bytes needed from the response.
class SlowServer
  def initialize(image_path)
    @image_data = File.binread(image_path)
  end

  def open
    tcp_server = TCPServer.new("127.0.0.1", 0)

    thread = Thread.new do
      loop do
        client = tcp_server.accept rescue break
        Thread.new(client) do |c|
          begin
            c.gets("\r\n\r\n")
            total_size = @image_data.bytesize + 5_000_000
            c.write "HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\nContent-Length: #{total_size}\r\n\r\n"
            c.write @image_data
            100.times do
              sleep 0.5
              c.write("\x00" * 1024)
            end
          rescue
          ensure
            c.close
          end
        end
      end
    end

    begin
      yield tcp_server.addr[1]
    ensure
      tcp_server.close
      thread.join(1)
    end
  end
end
