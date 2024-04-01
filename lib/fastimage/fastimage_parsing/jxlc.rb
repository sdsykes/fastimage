module FastImageParsing
  class Jxlc # :nodoc:
    attr_reader :width, :height

    LENGTHS = [9, 13, 18, 30]
    MULTIPLIERS = [1, 1.2, Rational(4, 3), 1.5, Rational(16, 9), 1.25, 2]
  
    def initialize(stream)
      @stream = stream
      @width, @height´ = nil
      @bit_counter = 0
      parse_jxlc
    end
    
    def parse_jxlc
      @words = @stream.read(6)[2..5].unpack('vv')

      # small mode allows for values <= 256 that are divisible by 8
      small = get_bits(1)
      if small == 1
        y = (get_bits(5) + 1) * 8
        x = x_from_ratio(y)
        if !x
          x = (get_bits(5) + 1) * 8
        end
        @width, @height = x, y
        return
      end

      len = LENGTHS[get_bits(2)]
      y = get_bits(len) + 1
      x = x_from_ratio(y)
      if !x
        len = LENGTHS[get_bits(2)]
        x = get_bits(len) + 1
      end
      @width, @height = x, y
    end

    def get_bits(size)
      if @words.size < (@bit_counter + size) / 16 + 1
        @words += @stream.read(4).unpack('vv')
      end

      dest_pos = 0
      dest = 0
      size.times do
        word = @bit_counter / 16
        source_pos = @bit_counter % 16
        dest |= ((@words[word] & (1 << source_pos)) > 0 ? 1 : 0) << dest_pos
        dest_pos += 1
        @bit_counter += 1
      end
      dest
    end

    def x_from_ratio(y)
      ratio = get_bits(3)
      if ratio == 0
        return nil
      else
        return (y * MULTIPLIERS[ratio - 1]).to_i
      end
    end
  end

  def parse_size_for_jxl
    if @stream.peek(2) == "\xFF\x0A".b
      JXL.new(@stream).read_size_header
    else
      bmff = IsoBmff.new(@stream)
      bmff.width_and_height
    end
  end
end
