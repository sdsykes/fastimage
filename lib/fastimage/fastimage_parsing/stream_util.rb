module FastImageParsing
  module StreamUtil # :nodoc:
    def read_byte
      read(1)[0].ord
    end
  
    def read_int
      read(2).unpack('n')[0]
    end
  
    def read_string_int
      value = []
      while read(1) =~ /(\d)/
        value << $1
      end
      value.join.to_i
    end
  end
end
