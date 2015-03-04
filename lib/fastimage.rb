# coding: ASCII-8BIT

# FastImage finds the size or type of an image given its uri.
# It is careful to only fetch and parse as much of the image as is needed to determine the result.
# It does this by using a feature of Net::HTTP that yields strings from the resource being fetched
# as soon as the packets arrive.
#
# No external libraries such as ImageMagick are used here, this is a very lightweight solution to
# finding image information.
#
# FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD and WEBP files.
#
# FastImage can also read files from the local filesystem by supplying the path instead of a uri.
# In this case FastImage reads the file in chunks of 256 bytes until
# it has enough. This is possibly a useful bandwidth-saving feature if the file is on a network
# attached disk rather than truly local.
#
# FastImage will automatically read from any object that responds to :read - for
# instance an IO object if that is passed instead of a URI.
#
# FastImage will follow up to 4 HTTP redirects to get the image.
#
# === Examples
#   require 'fastimage'
#
#   FastImage.size("http://stephensykes.com/images/ss.com_x.gif")
#   => [266, 56]
#   FastImage.type("http://stephensykes.com/images/pngimage")
#   => :png
#   FastImage.type("/some/local/file.gif")
#   => :gif
#   File.open("/some/local/file.gif", "r") {|io| FastImage.type(io)}
#   => :gif
#
# === References
# * http://snippets.dzone.com/posts/show/805
# * http://www.anttikupila.com/flash/getting-jpg-dimensions-with-as3-without-loading-the-entire-file/
# * http://pennysmalls.wordpress.com/2008/08/19/find-jpeg-dimensions-fast-in-pure-ruby-no-ima/
# * https://rubygems.org/gems/imagesize
# * https://github.com/remvee/exifr
#

require 'net/https'
require 'addressable/uri'
require 'fastimage/fbr.rb'
require 'delegate'
require 'pathname'
require 'zlib'

class FastImage
  attr_reader :size, :type

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

  # Returns an array containing the width and height of the image.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from a remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot size the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD and WEBP files.
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

  def initialize(uri, options={})
    @property = options[:type_only] ? :type : :size
    @timeout = options[:timeout] || DefaultTimeout
    @proxy_url = options[:proxy]
    @uri = uri

    if uri.respond_to?(:read)
      fetch_using_read(uri)
    else
      begin
        @parsed_uri = Addressable::URI.parse(uri)
      rescue Addressable::URI::InvalidURIError
        fetch_using_file_open
      else
        if @parsed_uri.scheme == "http" || @parsed_uri.scheme == "https"
          fetch_using_http
        else
          fetch_using_file_open
        end
      end
    end

    uri.rewind if uri.respond_to?(:rewind)

    raise SizeNotFound if options[:raise_on_failure] && @property == :size && !@size

  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET,
    ImageFetchFailure, Net::HTTPBadResponse, EOFError, Errno::ENOENT
    raise ImageFetchFailure if options[:raise_on_failure]
  rescue NoMethodError  # 1.8.7p248 can raise this due to a net/http bug
    raise ImageFetchFailure if options[:raise_on_failure]
  rescue UnknownImageType
    raise UnknownImageType if options[:raise_on_failure]
  rescue CannotParseImage
    if options[:raise_on_failure]
      if @property == :size
        raise SizeNotFound
      else
        raise ImageFetchFailure
      end
    end

  end

  private

  def fetch_using_http
    @redirect_count = 0

    fetch_using_http_from_parsed_uri
  end

  def fetch_using_http_from_parsed_uri
    setup_http
    @http.request_get(@parsed_uri.request_uri, 'Accept-Encoding' => 'identity') do |res|
      if res.is_a?(Net::HTTPRedirection) && @redirect_count < 4
        @redirect_count += 1
        begin
          newly_parsed_uri = Addressable::URI.parse(res['Location'])
          # The new location may be relative - check for that
          if newly_parsed_uri.scheme != "http" && newly_parsed_uri.scheme != "https"
            @parsed_uri.path = res['Location']
          else
            @parsed_uri = newly_parsed_uri
          end
        rescue Addressable::URI::InvalidURIError
        else
          fetch_using_http_from_parsed_uri
          break
        end
      end

      raise ImageFetchFailure unless res.is_a?(Net::HTTPSuccess)

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

  def proxy_uri
    begin
      if @proxy_url
        proxy = Addressable::URI.parse(@proxy_url)
      else
        proxy = ENV['http_proxy'] && ENV['http_proxy'] != "" ? Addressable::URI.parse(ENV['http_proxy']) : nil
      end
    rescue Addressable::URI::InvalidURIError
      proxy = nil
    end
    proxy
  end

  def setup_http
    proxy = proxy_uri

    if proxy
      @http = Net::HTTP::Proxy(proxy.host, proxy.port).new(@parsed_uri.host, @parsed_uri.inferred_port)
    else
      @http = Net::HTTP.new(@parsed_uri.host, @parsed_uri.inferred_port)
    end
    @http.use_ssl = (@parsed_uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http.open_timeout = @timeout
    @http.read_timeout = @timeout
  end

  def fetch_using_read(readable)
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
    File.open(@uri) do |s|
      fetch_using_read(s)
    end
  end

  def parse_packets(stream)
    @stream = stream

    begin
      result = send("parse_#{@property}")
      if result
        instance_variable_set("@#{@property}", result)
      else
        raise CannotParseImage
      end
    rescue FiberError
      raise CannotParseImage
    end
  end

  def parse_size
    @type = parse_type unless @type
    send("parse_size_for_#{@type}")
  end

  module StreamUtil # :nodoc:
    def read_byte
      read(1)[0].ord
    end

    def read_int
      read(2).unpack('n')[0]
    end
  end

  class FiberStream # :nodoc:
    include StreamUtil
    attr_reader :pos

    def initialize(read_fiber)
      @read_fiber = read_fiber
      @pos = 0
      @strpos = 0
      @str = ''
    end

    def peek(n)
      while @strpos + n - 1 >= @str.size
        unused_str = @str[@strpos..-1]
        new_string = @read_fiber.resume
        raise CannotParseImage if !new_string

        # we are dealing with bytes here, so force the encoding
        new_string.force_encoding("ASCII-8BIT") if String.method_defined? :force_encoding

        @str = unused_str + new_string
        @strpos = 0
      end

      result = @str[@strpos..(@strpos + n - 1)]
    end

    def read(n)
      result = peek(n)
      @strpos += n
      @pos += n
      result
    end
  end

  class IOStream < SimpleDelegator # :nodoc:
    include StreamUtil
  end

  def parse_type
    case @stream.peek(2)
    when "BM"
      :bmp
    when "GI"
      :gif
    when 0xff.chr + 0xd8.chr
      :jpeg
    when 0x89.chr + "P"
      :png
    when "II", "MM"
      :tiff
    when '8B'
      :psd
    when "\0\0"
      # ico has either a 1 (for ico format) or 2 (for cursor) at offset 3
      case @stream.peek(3).bytes.to_a.last
      when 1 then :ico
      when 2 then :cur
      end
    when "RI"
      if @stream.peek(12)[8..11] == "WEBP"
        :webp
      else
        raise UnknownImageType
      end
    else
      raise UnknownImageType
    end
  end

  def parse_size_for_ico
    @stream.read(8)[6..7].unpack('CC').map{|byte| byte == 0 ? 256 : byte }
  end
  alias_method :parse_size_for_cur, :parse_size_for_ico

  def parse_size_for_gif
    @stream.read(11)[6..10].unpack('SS')
  end

  def parse_size_for_png
    @stream.read(25)[16..24].unpack('NN')
  end

  def parse_size_for_jpeg
    loop do
      @state = case @state
      when nil
        @stream.read(2)
        :started
      when :started
        @stream.read_byte == 0xFF ? :sof : :started
      when :sof
        case @stream.read_byte
        when 0xe1 # APP1
          skip_chars = @stream.read_int - 2
          data = @stream.read(skip_chars)
          io = StringIO.new(data)
          if io.read(4) == "Exif"
            io.read(2)
            @exif = Exif.new(IOStream.new(io)) rescue nil
          end
          :started
        when 0xe0..0xef
          :skipframe
        when 0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF
          :readsize
        when 0xFF
          :sof
        else
          :skipframe
        end
      when :skipframe
        skip_chars = @stream.read_int - 2
        @stream.read(skip_chars)
        :started
      when :readsize
        s = @stream.read(3)
        height = @stream.read_int
        width = @stream.read_int
        width, height = height, width if @exif && @exif.rotated?
        return [width, height]
      end
    end
  end

  def parse_size_for_bmp
    d = @stream.read(32)[14..28]
    header = d.unpack("C")[0]

    result = if header == 40
               d[4..-1].unpack('l<l<')
             else
               d[4..8].unpack('SS')
             end

    # ImageHeight is expressed in pixels. The absolute value is necessary because ImageHeight can be negative
    [result.first, result.last.abs]
  end

  def parse_size_for_webp
    vp8 = @stream.read(16)[12..15]
    len = @stream.read(4).unpack("V")
    case vp8
    when "VP8 "
      parse_size_vp8
    when "VP8L"
      parse_size_vp8l
    when "VP8X"
      parse_size_vp8x
    else
      nil
    end
  end

  def parse_size_vp8
    w, h = @stream.read(10).unpack("@6vv")
    [w & 0x3fff, h & 0x3fff]
  end

  def parse_size_vp8l
    @stream.read(1) # 0x2f
    b1, b2, b3, b4 = @stream.read(4).bytes.to_a
    [1 + (((b2 & 0x3f) << 8) | b1), 1 + (((b4 & 0xF) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6))]
  end

  def parse_size_vp8x
    flags = @stream.read(4).unpack("C")[0]
    b1, b2, b3, b4, b5, b6 = @stream.read(6).unpack("CCCCCC")
    width, height = 1 + b1 + (b2 << 8) + (b3 << 16), 1 + b4 + (b5 << 8) + (b6 << 16)

    if flags & 8 > 0 # exif
      # parse exif for orientation
      # TODO: find or create test images for this
    end

    return [width, height]
  end

  class Exif # :nodoc:
    attr_reader :width, :height
    def initialize(stream)
      @stream = stream
      parse_exif
    end

    def rotated?
      @orientation && @orientation >= 5
    end

    private

    def get_exif_byte_order
      byte_order = @stream.read(2)
      case byte_order
      when 'II'
        @short, @long = 'v', 'V'
      when 'MM'
        @short, @long = 'n', 'N'
      else
        raise CannotParseImage
      end
    end

    def parse_exif_ifd
      tag_count = @stream.read(2).unpack(@short)[0]
      tag_count.downto(1) do
        type = @stream.read(2).unpack(@short)[0]
        @stream.read(6)
        data = @stream.read(2).unpack(@short)[0]
        case type
        when 0x0100 # image width
          @width = data
        when 0x0101 # image height
          @height = data
        when 0x0112 # orientation
          @orientation = data
        end
        if @width && @height && @orientation
          return # no need to parse more
        end
        @stream.read(2)
      end
    end

    def parse_exif
      @start_byte = @stream.pos

      get_exif_byte_order

      @stream.read(2) # 42

      offset = @stream.read(4).unpack(@long)[0]
      @stream.read(offset - 8)

      parse_exif_ifd
    end

  end

  def parse_size_for_tiff
    exif = Exif.new(@stream)
    if exif.rotated?
      [exif.height, exif.width]
    else
      [exif.width, exif.height]
    end
  end

  def parse_size_for_psd
    @stream.read(26).unpack("x14NN").reverse
  end
end
