class PassageCTSIdentifier < CTSIdentifier   
  
  PATH_PREFIX = 'CTS_XML_PASSAGES'
  IDENTIFIER_NAMESPACE = 'passages'
  FRIENDLY_NAME = "Passage Text"
  EDIT_ARTIFACT = true
  
  XML_VALIDATOR = JRubyXML::TEIAValidator
  
  def related_text
    self.publication.identifiers.select{|i| i.class == TeiCTSIdentifier}.last
  end
  
  
  def self.new_from_template(publication,passage_urn)    
    new_identifier = self.new(:name => passage_urn.sub!(/urn:cts:/,'').tr!(':','/'))
    new_identifier.publication = publication
    new_identifier.save!
    initial_content = new_identifier.file_template
    new_identifier.set_xml_content(initial_content, :comment => "dummy passage")
    commit_sha = new_identifier.get_recent_commit_sha()
    Rails.logger.info("UUID for passage #{commit_sha}")
    # TODO inventory should be carried along in identifier from creation as part of the path
    inventory = CTS::CTSLib.getInventory("perseus")
    document = new_identifier.related_text.content
    passage_xml = CTS::CTSLib.proxyGetPassage(inventory,document,new_identifier.id_attribute,commit_sha) 
    Rails.logger.info("Passage XML:#{passage_xml}")
    new_identifier.set_xml_content(passage_xml, :comment => "extracted passage")    
    return new_identifier
  end
    
  def before_commit(content)
    Rails.logger.info("Before commit content =" + content)
    PassageCTSIdentifier.preprocess(content)
  end
  
  def self.preprocess(content)
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt cts validate_passage.xsl})))
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
