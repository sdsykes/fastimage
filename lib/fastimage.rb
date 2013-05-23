# coding: ASCII-8BIT

# FastImage finds the size or type of an image given its uri.
# It is careful to only fetch and parse as much of the image as is needed to determine the result.
# It does this by using a feature of Net::HTTP that yields strings from the resource being fetched
# as soon as the packets arrive.
#
# No external libraries such as ImageMagick are used here, this is a very lightweight solution to 
# finding image information.
#
# FastImage knows about GIF, JPEG, BMP, TIFF and PNG files.
#
# FastImage can also read files from the local filesystem by supplying the path instead of a uri.
# In this case FastImage uses the open-uri library to read the file in chunks of 256 bytes until
# it has enough. This is possibly a useful bandwidth-saving feature if the file is on a network
# attached disk rather than truly local.
#
# New in v1.2.9, FastImage will automatically read from any object that responds to :read - for 
# instance an IO object if that is passed instead of a URI.
#
# New in v1.2.10 FastImage will follow up to 4 HTTP redirects to get the image.
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
# * http://imagesize.rubyforge.org/
# * https://github.com/remvee/exifr
#

require 'net/https'
require 'open-uri'
require 'fastimage/fbr.rb'

class FastImage
  attr_reader :size, :type
  
  attr_reader :bytes_read

  class FastImageException < StandardError # :nodoc:
  end
  class MoreCharsNeeded < FastImageException # :nodoc:
  end
  class UnknownImageType < FastImageException # :nodoc:
  end
  class ImageFetchFailure < FastImageException # :nodoc:
  end
  class SizeNotFound < FastImageException # :nodoc:
  end
  class CannotParseImage < FastImageException # :nodoc:
  end

  DefaultTimeout = 2
  
  LocalFileChunkSize = 256

  # Returns an array containing the width and height of the image.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from a remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot size the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # FastImage knows about GIF, JPEG, BMP, TIFF and PNG files.
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
  #   FastImage.type("http://pennysmalls.com/does_not_exist")
  #   => nil
  #   File.open("/some/local/file.gif", "r") {|io| FastImage.type(io)}
  #   => :gif
  #   FastImage.type("test/fixtures/test.tiff")
  #   => :tiff
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
    @uri = uri

    if uri.respond_to?(:read)
      fetch_using_read(uri)
    else
      begin
        @parsed_uri = URI.parse(uri)
      rescue URI::InvalidURIError
        fetch_using_open_uri
      else
        if @parsed_uri.scheme == "http" || @parsed_uri.scheme == "https"
          fetch_using_http
        else
          fetch_using_open_uri
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
          @parsed_uri = URI.parse(res['Location'])
        rescue URI::InvalidURIError
        else
          fetch_using_http_from_parsed_uri
          break
        end
      end

      raise ImageFetchFailure unless res.is_a?(Net::HTTPSuccess)

      @read_fiber = Fiber.new do
        res.read_body do |str|
          Fiber.yield str
        end
      end
      
      parse_packets
      
      break  # needed to actively quit out of the fetch
    end
  end

  def proxy_uri
    begin
      proxy = ENV['http_proxy'] && ENV['http_proxy'] != "" ? URI.parse(ENV['http_proxy']) : nil
    rescue URI::InvalidURIError
      proxy = nil
    end
    proxy
  end

  def setup_http
    proxy = proxy_uri

    if proxy
      @http = Net::HTTP::Proxy(proxy.host, proxy.port).new(@parsed_uri.host, @parsed_uri.port)
    else
      @http = Net::HTTP.new(@parsed_uri.host, @parsed_uri.port)
    end
    
    @http.use_ssl = (@parsed_uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http.open_timeout = @timeout
    @http.read_timeout = @timeout
  end

  def fetch_using_read(readable)
    @read_fiber = Fiber.new do
      while str = readable.read(LocalFileChunkSize)
        Fiber.yield str
      end
    end
    
    parse_packets
  end

  def fetch_using_open_uri
    open(@uri) do |s|
      fetch_using_read(s)
    end
  end

  def parse_packets
    @str = ""
    @str.force_encoding("ASCII-8BIT") if has_encoding?
    @strpos = 0
    @bytes_read = 0
    
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
    @strpos = 0
    send("parse_size_for_#{@type}")
  end

  def has_encoding?
    if @has_encoding.nil?
      @has_encoding = String.new.respond_to? :force_encoding
    else
      @has_encoding
    end
  end

  def get_chars(n)
    while @strpos + n - 1 >= @str.size
      unused_str = @str[@strpos..-1]
      new_string = @read_fiber.resume
      raise CannotParseImage if !new_string

      # we are dealing with bytes here, so force the encoding
      if has_encoding?
        new_string.force_encoding("ASCII-8BIT")
      end

      @bytes_read += new_string.size
      
      @str = unused_str + new_string
      @strpos = 0
    end
    
    result = @str[@strpos..(@strpos + n - 1)]
    @strpos += n
    result
  end

  def get_byte
    get_chars(1).unpack("C")[0]
  end

  def read_int(str)
    size_bytes = str.unpack("CC")
    (size_bytes[0] << 8) + size_bytes[1]
  end

  def parse_type
    case get_chars(2)
    when "BM"
      :bmp
    when "GI"
      :gif
    when 0xff.chr + 0xd8.chr
      :jpeg
    when 0x89.chr + "P"
      :png
    when "II"
      :tiff
    when "MM"
      :tiff
    else
      raise UnknownImageType
    end
  end

  def parse_size_for_gif
    get_chars(11)[6..10].unpack('SS')
  end

  def parse_size_for_png
    get_chars(25)[16..24].unpack('NN')
  end

  def parse_size_for_jpeg
    loop do
      @state = case @state
      when nil
        get_chars(2)
        :started
      when :started
        get_byte == 0xFF ? :sof : :started
      when :sof
        case get_byte
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
        @skip_chars = read_int(get_chars(2)) - 2
        :do_skip
      when :do_skip
        get_chars(@skip_chars)
        :started
      when :readsize
        s = get_chars(7)
        return [read_int(s[5..6]), read_int(s[3..4])]
      end
    end
  end

  def parse_size_for_bmp
    d = get_chars(29)[14..28]
    d.unpack("C")[0] == 40 ? d[4..-1].unpack('LL') : d[4..8].unpack('SS')
  end

  def parse_size_for_tiff
    byte_order = get_chars(2)
    case byte_order
      when 'II'; short, long = 'v', 'V'
      when 'MM'; short, long = 'n', 'N'
    end
    get_chars(2) # 42

    offset = get_chars(4).unpack(long)[0]
    get_chars(offset - 8)

    width = height = nil

    tag_count = get_chars(2).unpack(short)[0]
    tag_count.downto(1) do
      type = get_chars(2).unpack(short)[0]
      get_chars(6)
      data = get_chars(2).unpack(short)[0]
      case type
      when 0x0100 # image width
        width = data
      when 0x0101 # image height
        height = data
      end
      if width && height
        return [width, height]
      end
      get_chars(2)
    end
    
    raise CannotParseImage
  end
end
