module CTS
  require 'jruby_xml'
  require 'net/http'
  require "uri"
  
  CTS_NAMESPACE = "http://chs.harvard.edu/xmlns/cts3/ti"
  EXIST_HELPER_REPO = "http://localhost:8080/exist/rest/db/xq/CTS.xq?"
  EXIST_HELPER_REPO_PUT = "http://localhost:8080/exist/rest"
  
  module CTSLib
    class << self
      
      def getInventory(a_inventory)
         Rails.logger.info("Inventory" + self.getInventoriesHash()[a_inventory])
         response = Net::HTTP.get_response(
            URI.parse(self.getInventoriesHash()[a_inventory] + "&request=GetCapabilities"))
         results = JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(response.body),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
              %w{data xslt cts extract_reply.xsl})))
         return results
      end
      
      def getInventoriesHash()
        unless defined? @inventories_hash
          @inventories_hash = Hash.new
          @inventories_hash = { "perseus" => EXIST_HELPER_REPO + '&inv=perseussosol',
                                "epifacs" =>  EXIST_HELPER_REPO + '&inv=epi-ti'}
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
      
      def proxyGetValidReff(a_inventory,a_urn,a_level)
        if (a_inventory.nil? || a_inventory == '') 
          a_inventory = 'perseussosol'
        end    
        uri = URI.parse("#{EXIST_HELPER_REPO}request=GetValidReff&inv=#{a_inventory}&urn=#{a_urn}&level=#{a_level}")
        Rails.logger.info(uri.request_uri)
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          http.send_request('GET',uri.request_uri)
        end
        if (response.code == '200')
           Rails.logger.info(response.body)
           results = JRubyXML.apply_xsl_transform(
                   JRubyXML.stream_from_string(response.body),
                   JRubyXML.stream_from_file(File.join(RAILS_ROOT,
                   %w{data xslt cts validreff_urns.xsl})))  
        else
           nil
        end
      end
      
      def proxyGetPassage(a_inventory,a_document,a_urn,a_uuid)
          passage = ''
         
          # post inventory and get path for file put 
           uri = URI.parse("#{EXIST_HELPER_REPO}request=PutCitableText&xuuid=#{a_uuid}&urn=#{a_urn}")
           response = Net::HTTP.start(uri.host, uri.port) do |http|
                headers = {'Content-Type' => 'text/xml; charset=utf-8'}
                http.send_request('POST',uri.request_uri,a_inventory,headers)
           end
           if (response.code == '200')
            Rails.logger.info("Response=#{response.body}")
            path = JRubyXML.apply_xsl_transform(
                   JRubyXML.stream_from_string(response.body),
                   JRubyXML.stream_from_file(File.join(RAILS_ROOT,
                   %w{data xslt cts extract_reply_text.xsl})))  
            if (path != '')
              pathUri = URI.parse("#{EXIST_HELPER_REPO_PUT}#{path}")
              Rails.logger.info("Put Request #{pathUri}") 
              put_response = Net::HTTP.start(pathUri.host, pathUri.port) do |http|
                headers = {'Content-Type' => 'text/xml; charset=utf-8'}
                http.send_request('PUT', pathUri.request_uri, a_document,
headers)      
              end
              if (put_response.code == '201')
              # request passage
                rurl = URI.parse("#{EXIST_HELPER_REPO}request=GetPassagePlus&inv=#{a_uuid}&urn=#{a_urn}")
                Rails.logger.info("Passage Request #{rurl}") 
                psg_response = Net::HTTP.start(rurl.host, rurl.port) do |http|
                  http.send_request('GET', rurl.request_uri)
                end
                if (psg_response.code == '200')
                  Rails.logger.info("Passage retrieved #{psg_response.body}")
                  passage = JRubyXML.apply_xsl_transform(
                     JRubyXML.stream_from_string(psg_response.body),
                     JRubyXML.stream_from_file(File.join(RAILS_ROOT,
                     %w{data xslt cts extract_getpassage_reply.xsl})))  
                else
                  passage = "<error>Passage request failed #{psg_response.code} #{psg_response.msg}</error>"
                end # psg_response
              else
                passage = "<error>Put text failed #{put_response.code} #{put_response.msg}</error>"
              end # put_response
            else 
                passage = "<error>no path for put</error>"
            end # put_path          
           else # end post inventory
            passage = "<error>Inventory post failed #{response.code} #{response.msg}</error>"
          end
          # cleanup
         #  Net::HTTP.get_response(
         #       "#{EXIST_HELPER_REPO}&request=removeInventory&inv=#{invid}")
         # return passage
      end
      
      def proxyUpdatePassage()
          # load inventory  -> POST inventory -> returns unique identifier for inventory
          # load document -> POST document
          # update passage -> PUT CTS.xq?request=PutPassage&urn=urn&inventory=inv -> returns doc
          # cleanup
      end
      
    end #class
  end #module CTSLib
end #module CTS