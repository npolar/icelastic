module Icelastic
  class CsvWriter

    include Icelastic

    attr_accessor :env, :documents, :params

    def initialize(request, documents)
      self.env = request.env
      self.params = request.params
      self.documents = documents
    end

    def build
      # Build the csv document
      CSV.generate({:col_sep => "\t", :quote_char => "'"}) do |csv|
        csv << fields if fields?
        rows.each {|r| csv << r}
      end
    end

    private

    # True if there are user defined fields
    def fields?
      params.any?{|k,v| k == "fields"}
    end

    # Returns an array with the specified fields
    def fields
      fields? ? params['fields'].split(',') : keys
    end

    def keys
      k = []
      documents.each {|doc| k.concat(doc.keys)}
      k.uniq!
    end

    # Returns an array of arrays containing the column elements
    def rows
      docs = []
      documents.each do |doc|
        row = []
        fields.each_with_index {|field, i| row[i] = doc[field] ? handle_element(doc[field]) : "null"}
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