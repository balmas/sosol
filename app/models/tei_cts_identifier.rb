class TeiCTSIdentifier < CTSIdentifier   
  
  PATH_PREFIX = 'CTS_XML_TEI'
  
  FRIENDLY_NAME = "Full Text"
  
  IDENTIFIER_NAMESPACE = 'texts_edition'
  
  XML_VALIDATOR = JRubyXML::TEIAValidator
  
      
  def before_commit(content)
    TeiCTSIdentifier.preprocess(content)
  end
  
  def self.preprocess(content)
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt cts validate_teia.xsl})))
  end  
  
  def update_commentary(line_id, reference, comment_content = '', original_item_id = '', delete_comment = false)
    rewritten_xml =
      JRubyXML.apply_xsl_transform(
        JRubyXML.stream_from_string(
          TeiCTSIdentifier.preprocess(self.xml_content)),
        JRubyXML.stream_from_file(File.join(RAILS_ROOT,
          %w{data xslt ddb update_commentary.xsl})),
        :line_id => line_id,
        :reference => reference,
        :content => comment_content,
        :original_item_id => original_item_id,
        :delete_comment => (delete_comment ? 'true' : '')
      )
    
    self.set_xml_content(rewritten_xml, :comment => '')
  end
  
  def update_frontmatter_commentary(commentary_content, delete_commentary = false)
    rewritten_xml =
      JRubyXML.apply_xsl_transform(
        JRubyXML.stream_from_string(
          TeiCTSIdentifier.preprocess(self.xml_content)),
        JRubyXML.stream_from_file(File.join(RAILS_ROOT,
          %w{data xslt ddb update_frontmatter_commentary.xsl})),
        :content => commentary_content,
        :delete_commentary => (delete_commentary ? 'true' : '')
      )
    
    self.set_xml_content(rewritten_xml, :comment => '')
  end
 
  
  # Override REXML::Attribute#to_string so that attributes are defined
  # with double quotes instead of single quotes
  REXML::Attribute.class_eval( %q^
    def to_string
      %Q[#@expanded_name="#{to_s().gsub(/"/, '&quot;')}"]
    end
  ^ )
  
  
  def preview parameters = {}, xsl = nil
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(self.xml_content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        xsl ? xsl : %w{data xslt pn start-div-portlet_perseus.xsl})),
        parameters)
  end
  
end
