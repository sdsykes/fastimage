module FastImageParsing
  # HEIC/AVIF are a special case of the general ISO_BMFF format, in which all data is encapsulated in typed boxes,
  # with a mandatory ftyp box that is used to indicate particular file types. Is composed of nested "boxes". Each
  # box has a header composed of
  # - Size (32 bit integer)
  # - Box type (4 chars)
  # - Extended size: only if size === 1, the type field is followed by 64 bit integer of extended size
  # - Payload: Type-dependent
  class IsoBmff # :nodoc:
    attr_reader :width, :height
  
    def initialize(stream)
      @stream = stream
      @width, @height = nil
      parse_isobmff
    end
    
    def parse_isobmff
      @rotation = 0
      @max_size = nil
      @primary_box = nil
      @ipma_boxes = []
      @ispe_boxes = []
      @final_size = nil

      catch :finish do
        read_boxes!
      end

      if [90, 270].include?(@rotation)
        @final_size.reverse!
      end
      
      @width, @height = @final_size
    end

    private

    # Format specs: https://www.loc.gov/preservation/digital/formats/fdd/fdd000525.shtml

    # If you need to inspect a heic/heif file, use
    # https://gpac.github.io/mp4box.js/test/filereader.html
    def read_boxes!(max_read_bytes = nil)
      end_pos = max_read_bytes.nil? ? nil : @stream.pos + max_read_bytes
      index = 0

      loop do
        return if end_pos && @stream.pos >= end_pos

        box_type, box_size = read_box_header!

        case box_type
        when "meta"
          handle_meta_box(box_size)
        when "pitm"
          handle_pitm_box(box_size)
        when "ipma"
          handle_ipma_box(box_size)
        when "hdlr"
          handle_hdlr_box(box_size)
        when "iprp", "ipco"
          read_boxes!(box_size)
        when "irot"
          handle_irot_box
        when "ispe"
          handle_ispe_box(box_size, index)
        when "mdat"
          @stream.skip(box_size)
        when "jxlc"
          handle_jxlc_box(box_size)
        else
          @stream.skip(box_size)
        end

        index += 1
      end
    end

    def handle_irot_box
      @rotation = (read_uint8! & 0x3) * 90
    end

    def handle_ispe_box(box_size, index)
      throw :finish if box_size < 12

      data = @stream.read(box_size)
      width, height = data[4...12].unpack("N2")
      @ispe_boxes << { index: index, size: [width, height] }
    end

    def handle_hdlr_box(box_size)
      throw :finish if box_size < 12

      data = @stream.read(box_size)
      throw :finish if data[8...12] != "pict"
    end

    def handle_ipma_box(box_size)
      @stream.read(3)
      flags3 = read_uint8!
      entries_count = read_uint32!

      entries_count.times do
        id = read_uint16!
        essen_count = read_uint8!

        essen_count.times do
          property_index = read_uint8! & 0x7F

          if flags3 & 1 == 1
            property_index = (property_index << 7) + read_uint8!
          end

          @ipma_boxes << { id: id, property_index: property_index - 1 }
        end
      end
    end

    def handle_pitm_box(box_size)
      data = @stream.read(box_size)
      @primary_box = data[4...6].unpack("S>")[0]
    end

    def handle_meta_box(box_size)
      throw :finish if box_size < 4

      @stream.read(4)
      read_boxes!(box_size - 4)

      throw :finish if !@primary_box

      primary_indices = @ipma_boxes
                        .select { |box| box[:id] == @primary_box }
                        .map { |box| box[:property_index] }

      ispe_box = @ispe_boxes.find do |box|
        primary_indices.include?(box[:index])
      end

      if ispe_box
        @final_size = ispe_box[:size]
      end

      throw :finish
    end

    def handle_jxlc_box(box_size)
      jxlc = Jxlc.new(@stream)
      @final_size = [jxlc.width, jxlc.height]
      throw :finish
    end

    def read_box_header!
      size = read_uint32!
      type = @stream.read(4)
      size = read_uint64! - 8 if size == 1
      [type, size - 8]
    end

    def read_uint8!
      @stream.read(1).unpack("C")[0]
    end

    def read_uint16!
      @stream.read(2).unpack("S>")[0]
    end

    def read_uint32!
      @stream.read(4).unpack("N")[0]
    end

    def read_uint64!
      @stream.read(8).unpack("Q>")[0]
    end
  end
end
