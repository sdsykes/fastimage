module FastImageParsing
  class ImageBase # :nodoc:
    def initialize(stream)
      @stream = stream
    end
  
    # Implement in subclasses
    def dimensions
      raise NotImplementedError
    end
    
    # Implement in subclasses if appropriate
    def animated?
      nil
    end

    # Implement in subclasses if appropriate.
    # Returns [[x_resolution, y_resolution], units_symbol] or nil.
    # units_symbol is one of :inches, :centimeters, :meters, or :no_units.
    def resolution
      nil
    end
  end
end
