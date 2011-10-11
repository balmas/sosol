module CTS
  require 'jruby_xml'
  require 'net/http'
  require "uri"
  
  CTS_NAMESPACE = "http://chs.harvard.edu/xmlns/cts3/ti"
  
  module CTSLib
    class << self
        
      def getInventoriesHash()
        unless defined? @inventories_hash
          @inventories_hash = Hash.new
          @inventories_hash = { "epifacs" => "http://repos1.alpheios.net/exist/rest/db/xq/CTS.xq?&inv=epi-new" }
        end
        return @inventories_hash
      end
      
      def getEditionUrns(a_inventory)
        Rails.logger.info("Inventory" + self.getInventoriesHash()[a_inventory])
        response = Net::HTTP.get_response(
          URI.parse(self.getInventoriesHash()[a_inventory] + "&request=GetCapabilities"))
        results = JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(response.body),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
              %w{data xslt cts inventory_urns.xsl})))
        return results
      end
    end 
  end
end