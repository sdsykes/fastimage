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
  end
end
