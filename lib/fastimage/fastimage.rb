require_relative 'fastimage_parsing/image_base'
require_relative 'fastimage_parsing/stream_util'

require_relative 'fastimage_parsing/avif'
require_relative 'fastimage_parsing/bmp'
require_relative 'fastimage_parsing/exif'
require_relative 'fastimage_parsing/fiber_stream'
require_relative 'fastimage_parsing/gif'
require_relative 'fastimage_parsing/heic'
require_relative 'fastimage_parsing/ico'
require_relative 'fastimage_parsing/iso_bmff'
require_relative 'fastimage_parsing/jpeg'
require_relative 'fastimage_parsing/jxl'
require_relative 'fastimage_parsing/jxlc'
require_relative 'fastimage_parsing/png'
require_relative 'fastimage_parsing/psd'
require_relative 'fastimage_parsing/svg'
require_relative 'fastimage_parsing/tiff'
require_relative 'fastimage_parsing/type_parser'
require_relative 'fastimage_parsing/webp'

class FastImage
  include FastImageParsing

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
  class BadImageURI < FastImageException # :nodoc:
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
    :cur => Ico,
    :jxl => Jxl,
    :avif => Avif
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
  # FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, HEIC/HEIF, AVIF, PSD, SVG, WEBP and JXL files.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.size("https://switchstep.com/images/ios.gif")
  #   => [196, 283]
  #   FastImage.size("http://switchstep.com/images/ss_logo.png")
  #   => [300, 300]
  #   FastImage.size("https://upload.wikimedia.org/wikipedia/commons/0/09/Jpeg_thumb_artifacts_test.jpg")
  #   => [1280, 800]
  #   FastImage.size("https://eeweb.engineering.nyu.edu/~yao/EL5123/image/lena_gray.bmp")
  #   => [512, 512]
  #   FastImage.size("test/fixtures/test.jpg")
  #   => [882, 470]
  #   FastImage.size("http://switchstep.com/does_not_exist")
  #   => nil
  #   FastImage.size("http://switchstep.com/does_not_exist", :raise_on_failure=>true)
  #   => raises FastImage::ImageFetchFailure
  #   FastImage.size("http://switchstep.com/images/favicon.ico", :raise_on_failure=>true)
  #   => [16, 16]
  #   FastImage.size("http://switchstep.com/foo.ics", :raise_on_failure=>true)
  #   => raises FastImage::UnknownImageType
  #   FastImage.size("http://switchstep.com/images/favicon.ico", :raise_on_failure=>true, :timeout=>0.01)
  #   => raises FastImage::ImageFetchFailure
  #   FastImage.size("http://switchstep.com/images/faulty.jpg", :raise_on_failure=>true)
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
  #   FastImage.type("https://switchstep.com/images/ios.gif")
  #   => :gif
  #   FastImage.type("http://switchstep.com/images/ss_logo.png")
  #   => :png
  #   FastImage.type("https://upload.wikimedia.org/wikipedia/commons/0/09/Jpeg_thumb_artifacts_test.jpg")
  #   => :jpeg
  #   FastImage.type("https://eeweb.engineering.nyu.edu/~yao/EL5123/image/lena_gray.bmp")
  #   => :bmp
  #   FastImage.type("test/fixtures/test.jpg")
  #   => :jpeg
  #   FastImage.type("http://switchstep.com/does_not_exist")
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
    new(uri, options).type
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
    new(uri, options).animated
  end
  
  def initialize(uri, options={})
    @uri = uri
    @options = {
      :timeout          => DefaultTimeout,
      :raise_on_failure => false,
      :proxy            => nil,
      :http_header      => {}
    }.merge(options)
  end

  def type
    @property = :type
    fetch unless defined?(@type)
    @type
  end

  def size
    @property = :size
    begin
      fetch unless defined?(@size)
    rescue CannotParseImage
    end

    raise SizeNotFound if @options[:raise_on_failure] && !@size

    @size
  end

  def orientation
    size unless defined?(@size)
    @orientation ||= 1 if @size
  end

  def width
    size && @size[0]
  end

  def height
    size && @size[1]
  end

  def animated
    @property = :animated
    fetch unless defined?(@animated)
    @animated
  end
  
  def content_length
    @property = :content_length
    fetch unless defined?(@content_length)
    @content_length
  end

  # find an appropriate method to fetch the image according to the passed parameter
  def fetch
    raise BadImageURI if @uri.nil?

    if @uri.respond_to?(:read)
      fetch_using_read(@uri)
    elsif @uri.start_with?('data:')
      fetch_using_base64(@uri)
    else
      begin
        @parsed_uri = URI.parse(@uri)
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
  rescue UnknownImageType, BadImageURI, CannotParseImage
    raise if @options[:raise_on_failure]
  
  ensure
    @uri.rewind if @uri.respond_to?(:rewind)

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
    raise ImageFetchFailure unless @parsed_uri.is_a?(URI::HTTP)

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
      break if @property == :content_length

      read_fiber = Fiber.new do
        res.read_body do |str|
          Fiber.yield str
        end
        nil
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
          nil
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
    return @content_length = readable.size if @property == :content_length && readable.respond_to?(:size)

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
        nil
      end
    else
      read_fiber = Fiber.new do
        while str = readable.read(LocalFileChunkSize)
          Fiber.yield str
        end
        nil
      end
    end

    parse_packets FiberStream.new(read_fiber)
  end

  def fetch_using_file_open
    return @content_length = File.size?(@uri) if @property == :content_length

    File.open(@uri) do |s|
      fetch_using_read(s)
    end
  end

  def fetch_using_base64(uri)
    decoded = begin
      uri.split(',')[1].unpack("m").first
    rescue
      raise CannotParseImage
    end

    fetch_using_read StringIO.new(decoded)
  end
  
  def parse_packets(stream)
    @stream = stream

    begin
      @type = TypeParser.new(@stream).type unless defined?(@type)

      result = case @property
      when :type
        @type
      when :size
        parse_size
      when :animated
        parse_animated
      end

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

  def parser_class
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
