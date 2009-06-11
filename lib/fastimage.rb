# FastImage finds the size or type of an image given its uri.
# It is careful to only fetch and parse as much of the image as is needed to determine the result.
# It does this by using a feature of Net::HTTP that yields strings from the resource being fetched
# as soon as the packets arrive.
#
# No external libraries such as ImageMagick are used here, this is a very lightweight solution to 
# finding image information.
#
# FastImage knows about GIF, JPEG, BMP and PNG files.
#
# === Examples
#   require 'fastimage'
#
#   FastImage.size("http://stephensykes.com/images/ss.com_x.gif")
#   => [266, 56]
#   FastImage.type("http://stephensykes.com/images/pngimage")
#   => :png
#
# === References
# * http://snippets.dzone.com/posts/show/805
# * http://www.anttikupila.com/flash/getting-jpg-dimensions-with-as3-without-loading-the-entire-file/
# * http://pennysmalls.com/2008/08/19/find-jpeg-dimensions-fast-in-ruby/
# * http://imagesize.rubyforge.org/
#
require 'net/https'

class FastImage
  attr_reader :size, :type

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

  DefaultTimeout = 2

  # Returns an array containing the width and height of the image.
  # It will return nil if the image could not be fetched, or if the image type was not recognised.
  #
  # By default there is a timeout of 2 seconds for opening and reading from the remote server.
  # This can be changed by passing a :timeout => number_of_seconds in the options.
  #
  # If you wish FastImage to raise if it cannot size the image for any reason, then pass
  # :raise_on_failure => true in the options.
  #
  # FastImage knows about GIF, JPEG, BMP and PNG files.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.size("http://stephensykes.com/images/ss.com_x.gif")
  #   => [266, 56]
  #   FastImage.type("http://stephensykes.com/images/pngimage")
  #   => [16, 16]
  #   FastImage.size("http://farm4.static.flickr.com/3023/3047236863_9dce98b836.jpg")
  #   => [500, 375]
  #   FastImage.size("http://www-ece.rice.edu/~wakin/images/lena512.bmp")
  #   => [512, 512]
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
  # By default there is a timeout of 2 seconds for opening and reading from the remote server.
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
  #   => :jpg
  #   FastImage.type("http://www-ece.rice.edu/~wakin/images/lena512.bmp")
  #   => :bmp
  #   FastImage.type("http://pennysmalls.com/does_not_exist")
  #   => nil
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
    @type_only = options[:type_only]
    setup_http(uri, options)
    @http.request_get(@http_get_path) do |res|
      raise ImageFetchFailure unless res.is_a?(Net::HTTPSuccess)
      fetch_size_from_response(res)
    end
    raise SizeNotFound if options[:raise_on_failure] && !@size
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET, ImageFetchFailure
    raise ImageFetchFailure if options[:raise_on_failure]
  rescue UnknownImageType
    raise UnknownImageType if options[:raise_on_failure]
  end

  private

  def setup_http(uri, options)
    u = URI.parse(uri)
    @http = Net::HTTP.new(u.host, u.port)
    @http.use_ssl = (u.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http.open_timeout = options[:timeout] || DefaultTimeout
    @http.read_timeout = options[:timeout] || DefaultTimeout
    @http_get_path = u.request_uri
  end

  def fetch_type_from_response(res)
    fetch_from_response(res, :type){parse_type}
  end

  def fetch_size_from_response(res)
    fetch_from_response(res, :size){parse_size}
  end

  def fetch_from_response(res, item)
    @unused_str = ""
    res.read_body do |str|
      @str = @unused_str + str
      @strpos = 0
      begin
        result = yield
        if result 
          instance_variable_set("@#{item}", result)
          break
        end
      rescue MoreCharsNeeded
      end
    end
  end

  def parse_size
    @type = parse_type unless @type
    send("parse_size_for_#{@type}")
  end

  def get_chars(n)
    if @strpos + n - 1 >= @str.size
      @unused_str = @str[@strpos..-1]
      raise MoreCharsNeeded
    else
      result = @str[@strpos..(@strpos + n - 1)]
      @strpos += n
      result
    end
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
      :jpg
    when 0x89.chr + "P"
      :png
    else
      raise UnknownImageType
    end
  end

  def parse_size_for_gif
    get_chars(9)[4..8].unpack('SS')
  end

  def parse_size_for_png
    get_chars(23)[14..22].unpack('NN')
  end

  def parse_size_for_jpg
    loop do
      @state = case @state
      when nil
        get_chars(2)
        :started
      when :started
        get_byte == 0xFF ? :sof : :started          
      when :sof
        c = get_byte
        if (0xe0..0xef).include?(c)
          :skipframe
        elsif [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF].detect {|r| r.include? c}
          :readsize
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
    d = get_chars(27)[12..26]
    d[0] == 40 ? d[4..-1].unpack('LL') : d[4..8].unpack('SS')
  end
end
