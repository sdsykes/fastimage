module FastImageParsing
  class TypeParser
    def initialize(stream)
      @stream = stream
    end
    
    # type will use peek to get enough bytes to determing the type of the image
    def type
      parsed_type = case @stream.peek(2)
      when "BM"
        :bmp
      when "GI"
        :gif
      when 0xff.chr + 0xd8.chr
        :jpeg
      when 0x89.chr + "P"
        :png
      when "II", "MM"
        case @stream.peek(11)[8..10]
        when "APC", "CR\002"
          nil  # do not recognise CRW or CR2 as tiff
        else
          :tiff
        end
      when '8B'
        :psd
      when "\xFF\x0A".b
        :jxl
      when "\0\0"
        case @stream.peek(3).bytes.to_a.last
        when 0
          # http://www.ftyps.com/what.html
          case @stream.peek(12)[4..-1]
          when "ftypavif"
            :avif
          when "ftypavis"
            :avif
          when "ftypheic"
            :heic
          when "ftypmif1"
            :heif
          else
            if @stream.peek(7)[4..-1] == 'JXL'
              :jxl
            end
          end
        # ico has either a 1 (for ico format) or 2 (for cursor) at offset 3
        when 1 then :ico
        when 2 then :cur
        end
      when "RI"
        :webp if @stream.peek(12)[8..11] == "WEBP"
      when "<s"
        :svg if @stream.peek(4) == "<svg"
      when /\s\s|\s<|<[?!]/, 0xef.chr + 0xbb.chr
        # Peek 10 more chars each time, and if end of file is reached just raise
        # unknown. We assume the <svg tag cannot be within 10 chars of the end of
        # the file, and is within the first 1000 chars.
        begin
          :svg if (1..100).detect {|n| @stream.peek(10 * n).include?("<svg")}
        rescue FiberError, FastImage::CannotParseImage
          nil
        end
      end

      parsed_type or raise FastImage::UnknownImageType
    end
  end
end
