module FastImageParsing
  class IOStream < SimpleDelegator # :nodoc:
    include StreamUtil
  end
  
  class Jpeg < ImageBase # :nodoc:
    def dimensions
      exif = nil
      state = nil
      loop do
        state = case state
        when nil
          @stream.skip(2)
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
              new_exif = Exif.new(IOStream.new(io)) rescue nil
              exif ||= new_exif # only use the first APP1 segment
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
