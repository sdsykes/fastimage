module FastImageParsing
  class Exif # :nodoc:
    attr_reader :width, :height, :orientation
  
    def initialize(stream)
      @stream = stream
      @width, @height, @orientation = nil
      parse_exif
    end
  
    def rotated?
      @orientation >= 5
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
      if @stream.respond_to?(:skip)
        @stream.skip(offset - 8)
      else
        @stream.read(offset - 8)
      end
  
      parse_exif_ifd
  
      @orientation ||= 1
    end
  end
end
