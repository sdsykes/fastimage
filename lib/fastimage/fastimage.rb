class FastImage
  include FastImageParsing

  VERSION = "2.2.3"
  
  attr_reader :size, :type, :content_length, :orientation, :animated

  attr_reader :bytes_read

  class FastImageException < StandardError # :nodoc:
  end
  class UnknownImageType < FastImageException # :nodoc:
  end
  class ImageFetchFailure < FastImageException # :nodoc:
  end
  class SizeNotFound < FastImageException # :nodoc:
  end
  class CannotParseImage < FastImageException # :nodoc:
  end

  DefaultTimeout = 2 unless const_defined?(:DefaultTimeout)

  LocalFileChunkSize = 256 unless const_defined?(:LocalFileChunkSize)

  private
  
  Parsers = {
    :bmp => Bmp,
    :gif => Gif,
    :jpeg => Jpeg,
    :png => Png,
    :tiff => Tiff,
    :psd => Psd,
    :heic => Heic,
    :heif => Heic,
    :webp => Webp,
    :svg => Svg,
    :ico => Ico,
    :cur => Ico
  }.freeze
  
  public
  
  SUPPORTED_IMAGE_TYPES = Parsers.keys.freeze
  
  # Returns an array containing the width and height of the image.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from a remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot size the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD, SVG and WEBP files.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.size("http://stephensykes.com/images/ss.com_x.gif")
  #   => [266, 56]
  #   FastImage.size("http://stephensykes.com/images/pngimage")
  #   => [16, 16]
  #   FastImage.size("http://farm4.static.flickr.com/3023/3047236863_9dce98b836.jpg")
  #   => [500, 375]
  #   FastImage.size("http://www-ece.rice.edu/~wakin/images/lena512.bmp")
  #   => [512, 512]
  #   FastImage.size("test/fixtures/test.jpg")
  #   => [882, 470]
  #   FastImage.size("http://pennysmalls.com/does_not_exist")
  #   => nil
  #   FastImage.size("http://pennysmalls.com/does_not_exist", :raise_on_failure=>true)
  #   => raises FastImage::ImageFetchFailure
  #   FastImage.size("http://stephensykes.com/favicon.ico", :raise_on_failure=>true)
  #   => [16, 16]
  #   FastImage.size("http://stephensykes.com/images/squareBlue.icns", :raise_on_failure=>true)
  #   => raises FastImage::UnknownImageType
  #   FastImage.size("http://stephensykes.com/favicon.ico", :raise_on_failure=>true, :timeout=>0.01)
  #   => raises FastImage::ImageFetchFailure
  #   FastImage.size("http://stephensykes.com/images/faulty.jpg", :raise_on_failure=>true)
  #   => raises FastImage::SizeNotFound
  #
  # === Supported options
  # [:timeout]
  #   Overrides the default timeout of 2 seconds.  Applies both to reading from and opening the http connection.
  # [:raise_on_failure]
  #   If set to true causes an exception to be raised if the image size cannot be found for any reason.
  #
  def self.size(uri, options={})
    new(uri, options).size
  end

  # Returns an symbol indicating the image type fetched from a uri.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from a remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot find the type of the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.type("http://stephensykes.com/images/ss.com_x.gif")
  #   => :gif
  #   FastImage.type("http://stephensykes.com/images/pngimage")
  #   => :png
  #   FastImage.type("http://farm4.static.flickr.com/3023/3047236863_9dce98b836.jpg")
  #   => :jpeg
  #   FastImage.type("http://www-ece.rice.edu/~wakin/images/lena512.bmp")
  #   => :bmp
  #   FastImage.type("test/fixtures/test.jpg")
  #   => :jpeg
  #   FastImage.type("http://stephensykes.com/does_not_exist")
  #   => nil
  #   File.open("/some/local/file.gif", "r") {|io| FastImage.type(io)}
  #   => :gif
  #   FastImage.type("test/fixtures/test.tiff")
  #   => :tiff
  #   FastImage.type("test/fixtures/test.psd")
  #   => :psd
  #
  # === Supported options
  # [:timeout]
  #   Overrides the default timeout of 2 seconds.  Applies both to reading from and opening the http connection.
  # [:raise_on_failure]
  #   If set to true causes an exception to be raised if the image type cannot be found for any reason.
  #
  def self.type(uri, options={})
    new(uri, options.merge(:type_only=>true)).type
  end

  # Returns a boolean value indicating the image is animated.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from a remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot find the type of the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.animated?("test/fixtures/test.gif")
  #   => false
  #   FastImage.animated?("test/fixtures/animated.gif")
  #   => true
  #
  # === Supported options
  # [:timeout]
  #   Overrides the default timeout of 2 seconds.  Applies both to reading from and opening the http connection.
  # [:raise_on_failure]
  #   If set to true causes an exception to be raised if the image type cannot be found for any reason.
  #
  def self.animated?(uri, options={})
    new(uri, options.merge(:animated_only=>true)).animated
  end

  def initialize(uri, options={})
    @uri = uri
    @options = {
      :type_only        => false,
      :timeout          => DefaultTimeout,
      :raise_on_failure => false,
      :proxy            => nil,
      :http_header      => {}
    }.merge(options)

    @property = if @options[:animated_only]
      :animated
    elsif @options[:type_only]
      :type
    else
      :size
    end

    @type, @state = nil

    if uri.respond_to?(:read)
      fetch_using_read(uri)
    elsif uri.start_with?('data:')
      fetch_using_base64(uri)
    else
      begin
        @parsed_uri = URI.parse(uri)
      rescue URI::InvalidURIError
        fetch_using_file_open
      else
        if @parsed_uri.scheme == "http" || @parsed_uri.scheme == "https"
          fetch_using_http
        else
          fetch_using_file_open
        end
      end
    end

    raise SizeNotFound if @options[:raise_on_failure] && @property == :size && !@size

  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET,
    Errno::ENETUNREACH, ImageFetchFailure, Net::HTTPBadResponse, EOFError, Errno::ENOENT,
    OpenSSL::SSL::SSLError
    raise ImageFetchFailure if @options[:raise_on_failure]
  rescue UnknownImageType
    raise if @options[:raise_on_failure]
  rescue CannotParseImage
    if @options[:raise_on_failure]
      if @property == :size
        raise SizeNotFound
      else
        raise ImageFetchFailure
      end
    end

  ensure
    uri.rewind if uri.respond_to?(:rewind)
  end

  private

  def fetch_using_http
    @redirect_count = 0

    fetch_using_http_from_parsed_uri
  end

  # Some invalid locations need escaping
  def escaped_location(location)
    begin
      URI(location)
    rescue URI::InvalidURIError
      ::URI::DEFAULT_PARSER.escape(location)
    else
      location
    end
  end

  def fetch_using_http_from_parsed_uri
    http_header = {'Accept-Encoding' => 'identity'}.merge(@options[:http_header])

    setup_http
    @http.request_get(@parsed_uri.request_uri, http_header) do |res|
      if res.is_a?(Net::HTTPRedirection) && @redirect_count < 4
        @redirect_count += 1
        begin
          location = res['Location']
          raise ImageFetchFailure if location.nil? || location.empty?

          @parsed_uri = URI.join(@parsed_uri, escaped_location(location))
        rescue URI::InvalidURIError
        else
          fetch_using_http_from_parsed_uri
          break
        end
      end

      raise ImageFetchFailure unless res.is_a?(Net::HTTPSuccess)

      @content_length = res.content_length

      read_fiber = Fiber.new do
        res.read_body do |str|
          Fiber.yield str
        end
      end

      case res['content-encoding']
      when 'deflate', 'gzip', 'x-gzip'
        begin
          gzip = Zlib::GzipReader.new(FiberStream.new(read_fiber))
        rescue FiberError, Zlib::GzipFile::Error
          raise CannotParseImage
        end

        read_fiber = Fiber.new do
          while data = gzip.readline
            Fiber.yield data
          end
        end
      end

      parse_packets FiberStream.new(read_fiber)

      break  # needed to actively quit out of the fetch
    end
  end

  def protocol_relative_url?(url)
    url.start_with?("//")
  end

  def proxy_uri
    begin
      if @options[:proxy]
        proxy = URI.parse(@options[:proxy])
      else
        proxy = ENV['http_proxy'] && ENV['http_proxy'] != "" ? URI.parse(ENV['http_proxy']) : nil
      end
    rescue URI::InvalidURIError
      proxy = nil
    end
    proxy
  end

  def setup_http
    proxy = proxy_uri

    if proxy
      @http = Net::HTTP::Proxy(proxy.host, proxy.port, proxy.user, proxy.password).new(@parsed_uri.host, @parsed_uri.port)
    else
      @http = Net::HTTP.new(@parsed_uri.host, @parsed_uri.port)
    end
    @http.use_ssl = (@parsed_uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http.open_timeout = @options[:timeout]
    @http.read_timeout = @options[:timeout]
  end

  def fetch_using_read(readable)
    readable.rewind if readable.respond_to?(:rewind)
    # Pathnames respond to read, but always return the first
    # chunk of the file unlike an IO (even though the
    # docuementation for it refers to IO). Need to supply
    # an offset in this case.
    if readable.is_a?(Pathname)
      read_fiber = Fiber.new do
        offset = 0
        while str = readable.read(LocalFileChunkSize, offset)
          Fiber.yield str
          offset += LocalFileChunkSize
        end
      end
    else
      read_fiber = Fiber.new do
        while str = readable.read(LocalFileChunkSize)
          Fiber.yield str
        end
      end
    end

    parse_packets FiberStream.new(read_fiber)
  end

  def fetch_using_file_open
    @content_length = File.size?(@uri)
    File.open(@uri) do |s|
      fetch_using_read(s)
    end
  end

  def fetch_using_base64(uri)
    decoded = begin
      Base64.decode64(uri.split(',')[1])
    rescue
      raise CannotParseImage
    end
    @content_length = decoded.size
    fetch_using_read StringIO.new(decoded)
  end

  def parse_packets(stream)
    @stream = stream

    begin
      result = send("parse_#{@property}")
      if result != nil
        # extract exif orientation if it was found
        if @property == :size && result.size == 3
          @orientation = result.pop
        else
          @orientation = 1
        end

        instance_variable_set("@#{@property}", result)
      else
        raise CannotParseImage
      end
    rescue FiberError
      raise CannotParseImage
    end
  end

  def parse_type
    TypeParser.new(@stream).type
  end
  
  def parser_class
    @type ||= parse_type
    klass = Parsers[@type]
    raise UnknownImageType unless klass
    klass
  end
  
  def parse_size
    parser_class.new(@stream).dimensions
  end
  
  def parse_animated
    parser_class.new(@stream).animated?
  end
end
