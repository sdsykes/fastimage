module FastImageParsing
  class FiberStream # :nodoc:
    include StreamUtil
    attr_reader :pos
  
    # read_fiber should return nil if it no longer has anything to return when resumed
    # so the result of the whole Fiber block should be set to be nil in case yield is no
    # longer called
    def initialize(read_fiber)
      @read_fiber = read_fiber
      @pos = 0
      @strpos = 0
      @str = ''
    end
  
    # Peeking beyond the end of the input will raise
    def peek(n)
      while @strpos + n > @str.size
        unused_str = @str[@strpos..-1]
  
        new_string = @read_fiber.resume
        raise FastImage::CannotParseImage if !new_string
        # we are dealing with bytes here, so force the encoding
        new_string.force_encoding("ASCII-8BIT") if new_string.respond_to? :force_encoding
  
        @str = unused_str + new_string
        @strpos = 0
      end
  
      @str[@strpos, n]
    end
  
    def read(n)
      result = peek(n)
      @strpos += n
      @pos += n
      result
    end
  
    def skip(n)
      discarded = 0
      fetched = @str[@strpos..-1].size
      while n > fetched
        discarded += @str[@strpos..-1].size
        new_string = @read_fiber.resume
        raise FastImage::CannotParseImage if !new_string
  
        new_string.force_encoding("ASCII-8BIT") if new_string.respond_to? :force_encoding
  
        fetched += new_string.size
        @str = new_string
        @strpos = 0
      end
      @strpos = @strpos + n - discarded
      @pos += n
    end
  end
end
