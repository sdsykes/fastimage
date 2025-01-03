module FastImageParsing
  class Svg < ImageBase # :nodoc:
    def dimensions
      @width, @height, @ratio, @viewbox_width, @viewbox_height = nil

      parse_svg
      
      if @width && @height
        [@width, @height]
      elsif @width && @ratio
        [@width, @width / @ratio]
      elsif @height && @ratio
        [@height * @ratio, @height]
      elsif @viewbox_width && @viewbox_height
        [@viewbox_width, @viewbox_height]
      else
        nil
      end
    end
  
    private
  
    def parse_svg
      attr_name = []
      state = nil
  
      while (char = @stream.read(1)) && state != :stop do
        case char
        when "="
          if attr_name.join =~ /width/i
            @stream.read(1)
            @width = @stream.read_string_int
            return if @height
          elsif attr_name.join =~ /height/i
            @stream.read(1)
            @height = @stream.read_string_int
            return if @width
          elsif attr_name.join =~ /viewbox/i
            values = attr_value.split(/\s/)
            if values[2].to_f > 0 && values[3].to_f > 0
              @ratio = values[2].to_f / values[3].to_f
              @viewbox_width = values[2].to_i
              @viewbox_height = values[3].to_i
            end
          end
        when /\w/
          attr_name << char
        when "<"
          attr_name = [char]
        when ">"
          state = :stop if state == :started
        else
          state = :started if attr_name.join == "<svg"
          attr_name.clear
        end
      end
    end
  
    def attr_value
      @stream.read(1)
  
      value = []
      while @stream.read(1) =~ /([^"])/
        value << $1
      end
      value.join
    end
  end
end
