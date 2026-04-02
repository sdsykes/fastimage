module FastImageParsing
  class Exif # :nodoc:
    attr_reader :width, :height, :orientation, :x_resolution, :y_resolution, :resolution_unit

    TAG_IMAGE_WIDTH    = 0x0100
    TAG_IMAGE_HEIGHT   = 0x0101
    TAG_ORIENTATION    = 0x0112
    TAG_X_RESOLUTION   = 0x011A
    TAG_Y_RESOLUTION   = 0x011B
    TAG_RESOLUTION_UNIT = 0x0128

    DATA_TYPE_LONG     = 4
    DATA_TYPE_RATIONAL = 5

    def initialize(stream, parse_resolution: false)
      @stream = stream
      @width, @height, @orientation = nil
      @x_resolution, @y_resolution, @resolution_unit = nil
      @parse_resolution = parse_resolution
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
        raise FastImage::CannotParseImage
      end
    end

    def parse_exif_ifd
      tag_count = @stream.read(2).unpack(@short)[0]
      @rational_offsets = {}

      tag_count.downto(1) do
        type = @stream.read(2).unpack(@short)[0]
        data_type = @stream.read(2).unpack(@short)[0]
        @stream.read(4)

        case data_type
        when DATA_TYPE_RATIONAL # value field is an offset to 8-byte rational
          offset = @stream.read(4).unpack(@long)[0]
          if @parse_resolution && (type == TAG_X_RESOLUTION || type == TAG_Y_RESOLUTION)
            @rational_offsets[type] = offset
          end
        when DATA_TYPE_LONG
          data = @stream.read(4).unpack(@long)[0]
          case type
          when TAG_IMAGE_WIDTH  then @width = data
          when TAG_IMAGE_HEIGHT then @height = data
          when TAG_ORIENTATION  then @orientation = data
          end
        else # SHORT and others that fit in 2+2 bytes
          data = @stream.read(2).unpack(@short)[0]
          @stream.read(2)
          case type
          when TAG_IMAGE_WIDTH    then @width = data
          when TAG_IMAGE_HEIGHT   then @height = data
          when TAG_ORIENTATION    then @orientation = data
          when TAG_RESOLUTION_UNIT then @resolution_unit = data if @parse_resolution
          end
        end

        if @width && @height && @orientation
          if @parse_resolution
            # Stop early only when all resolution data is also collected
            break if @rational_offsets.key?(TAG_X_RESOLUTION) && @rational_offsets.key?(TAG_Y_RESOLUTION) && @resolution_unit
          else
            return
          end
        end
      end

      read_rational_resolution if @parse_resolution && @rational_offsets.any?
    end

    def read_rational_resolution
      sorted = @rational_offsets.sort_by { |_, off| off }
      sorted.each do |tag, offset|
        absolute_pos = @start_byte + offset
        skip_amount = absolute_pos - @stream.pos
        next if skip_amount < 0

        if skip_amount > 0
          if @stream.respond_to?(:skip)
            @stream.skip(skip_amount)
          else
            @stream.read(skip_amount)
          end
        end

        num = @stream.read(4).unpack(@long)[0]
        den = @stream.read(4).unpack(@long)[0]
        case tag
        when TAG_X_RESOLUTION then @x_resolution = den > 0 ? num.to_f / den : nil
        when TAG_Y_RESOLUTION then @y_resolution = den > 0 ? num.to_f / den : nil
        end
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
