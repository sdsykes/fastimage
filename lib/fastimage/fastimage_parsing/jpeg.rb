module FastImageParsing
  class IOStream < SimpleDelegator # :nodoc:
    include StreamUtil
  end
  
  class Jpeg < ImageBase # :nodoc:
    MARKER_APP0       = 0xE0
    MARKER_APP1       = 0xE1
    MARKER_APP_RANGE  = (0xE0..0xEF)
    MARKER_SOF_RANGE  = [*(0xC0..0xC3), *(0xC5..0xC7), *(0xC9..0xCB), *(0xCD..0xCF)]
    MARKER_SOS        = 0xDA
    MARKER_EOI        = 0xD9
    MARKER_BYTE       = 0xFF

    JFIF_UNIT_ASPECT_RATIO  = 0
    JFIF_UNIT_INCHES        = 1
    JFIF_UNIT_CENTIMETERS   = 2

    def resolution
      exif_resolution = nil
      state = nil
      loop do
        state = case state
        when nil
          @stream.skip(2)
          :started
        when :started
          @stream.read_byte == MARKER_BYTE ? :sof : :started
        when :sof
          case @stream.read_byte
          when MARKER_APP0
            length = @stream.read_int - 2
            data = @stream.read(length)
            if data[0, 5] == "JFIF\0"
              units = data[7].ord
              x_density, y_density = data[8, 4].unpack("nn")
              unit_sym = case units
              when JFIF_UNIT_INCHES       then :inches
              when JFIF_UNIT_CENTIMETERS  then :centimeters
              else :no_units
              end
              return [[x_density, y_density], unit_sym]
            end
            :started
          when MARKER_APP1
            length = @stream.read_int - 2
            data = @stream.read(length)
            if exif_resolution.nil? && data[0, 6] == "Exif\0\0"
              io = StringIO.new(data[6..])
              exif = Exif.new(IOStream.new(io), parse_resolution: true) rescue nil
              if exif&.x_resolution && exif&.y_resolution
                unit_sym = case exif.resolution_unit
                when Exif::RESOLUTION_UNIT_NO_UNITS    then :no_units
                when Exif::RESOLUTION_UNIT_CENTIMETERS then :centimeters
                else :inches
                end
                exif_resolution = [[exif.x_resolution, exif.y_resolution], unit_sym]
              end
            end
            :started
          when MARKER_BYTE
            :sof
          when *MARKER_SOF_RANGE, MARKER_SOS, MARKER_EOI
            return exif_resolution
          else
            :skipframe
          end
        when :skipframe
          skip_chars = @stream.read_int - 2
          @stream.skip(skip_chars)
          :started
        end
      end
    end

    def dimensions
      exif = nil
      state = nil
      loop do
        state = case state
        when nil
          @stream.skip(2)
          :started
        when :started
          @stream.read_byte == MARKER_BYTE ? :sof : :started
        when :sof
          case @stream.read_byte
          when MARKER_APP1
            skip_chars = @stream.read_int - 2
            data = @stream.read(skip_chars)
            io = StringIO.new(data)
            if io.read(4) == "Exif"
              io.read(2)
              new_exif = Exif.new(IOStream.new(io)) rescue nil
              exif ||= new_exif # only use the first APP1 segment
            end
            :started
          when MARKER_APP_RANGE
            :skipframe
          when *MARKER_SOF_RANGE
            :readsize
          when MARKER_BYTE
            :sof
          else
            :skipframe
          end
        when :skipframe
          skip_chars = @stream.read_int - 2
          @stream.skip(skip_chars)
          :started
        when :readsize
          @stream.skip(3)
          height = @stream.read_int
          width = @stream.read_int
          width, height = height, width if exif && exif.rotated?
          return [width, height, exif ? exif.orientation : 1]
        end
      end
    end
  end
end
