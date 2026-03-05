# frozen_string_literal: true
require 'webrick'
require 'webrick/https'
require 'openssl'

# A local HTTPS server with a self-signed certificate.
# Used to verify that FastImage handles SSL connections.
class HTTPSServer
  def initialize(replies)
    @replies = replies
  end

  def open
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=localhost")
    cert.not_before = Time.now
    cert.not_after = Time.now + 600
    cert.public_key = key.public_key
    cert.serial = 1
    cert.sign(key, OpenSSL::Digest::SHA256.new)

    server = WEBrick::HTTPServer.new(
      Port: 0,
      SSLEnable: true,
      SSLCertificate: cert,
      SSLPrivateKey: key,
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )

    @replies.each do |path, (content_type, body)|
      server.mount_proc(path) do |_req, res|
        res['Content-Type'] = content_type
        res.body = body
      end
    end

    thread = Thread.new { server.start }

    begin
      yield server.config[:Port]
    ensure
      server.shutdown
      thread.join
    end
  end
end
