module Icelastic
  module ResponseWriter
    class Csv

      attr_accessor :env, :documents, :params

      ALIAS_TOKEN = ":"
      
      def self.format  
        "csv"
      end
      
      def self.from
        ResponseWriter::Feed
      end
      
      def self.type
        "text/plain"
      end

      def initialize(request, feed)
        self.env = request.env
        self.params = request.params
        self.documents = feed["feed"]["stats"] ? feed["feed"]["stats"] : feed["feed"]["entries"]
      end
      


      def build
        # Build the csv document
        CSV.generate({:col_sep => "\t", :quote_char => "'"}) do |csv|
          csv << header
          rows.each {|r| csv << r}
        end
      end

      private

      # Document header
      def header
        fields? ? field_headers : doc_headers
      end

      # Field keys
      def keys
        fields? ? fields : doc_headers
      end

      # Tries to generate a complete header from the json keys
      def doc_headers
        h = []
        documents.slice(0,100).each {|doc| h.concat(doc.keys).uniq!}
        h
      end

      # True if there are user defined fields
      def fields?
        params.keys.include?("fields")
      end

      # @see Icelastic::QuerySegment::Paging.source_filter Depends on the source filter handling alias syntax
      def field_headers
        extract_field_arguments {|a, token| a.split(token).first}
      end

      # Returns an array with the specified fields
      def fields
        extract_field_arguments {|a, token| a.split(token).last}
      end

      # Can be used to perform an argument operation using the ALIAS_TOKEN.
      # The block is used to specify an operation (in our case split). If
      # the field can't be split into arguments it returns the field value.
      # @see #field_headers
      # @see #fields
      def extract_field_arguments(&block)
        params['fields'].split(',').map{|f| f =~ /#{ALIAS_TOKEN}/ ? block.call(f, ALIAS_TOKEN) : f }
      end

      # Returns an array of arrays containing the column elements
      def rows
        docs = []
        documents.each do |doc|
          row = []
          keys.each_with_index {|field, i| row[i] = handle_sub_fields(field, doc)}
          docs << row
        end
        docs
      end

      def handle_element(element)
        case element
        when Hash then handle_hash(element).to_json.gsub(/\\/,"")
        when Array then handle_array(element).join("|")
        else element
        end
      end

      def handle_sub_fields(field, doc)
        arguments = field.split(".") # Split chained fields on the dot => person.first_name
        val = doc[arguments.shift] # Initialize with the first argument field

        val.nil? ? "null" : grab_sub_value(val, arguments)
      end

      # Use the field arguments to dig into the structure and retrieve the bottom value
      def grab_sub_value(val, args)
        args.each do |a|
          if val.is_a?(Array)
            val = val.any? ? map_array_to_object_field(a, val) : "null"
          else
            val.nil? ? (return "null") : (val = val[a]) # Once the value becomes nil return "null" and bail
          end
        end

        handle_element(val)
      end

      def map_array_to_object_field(field, array)
        array.map{|e| e[field].nil? ? "null" : e[field]}
      end

      # Remap hash values to the proper format
      def handle_hash(element)
        element.each {|k,v| element[k] = handle_element(v)}
      end

      # Remap array elements to the proper format
      def handle_array(element)
        element.map! {|e| handle_element(e)}
      end

    end
  end
end
