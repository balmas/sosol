class EpiTransCTSIdentifier < EpiCTSIdentifier   
  
  PATH_PREFIX = 'CTS_XML_EpiDoc'
  COLLECTION_XML_PATH = 'CTS_INVENTORIES/epigraphy.xml'
  TEMPORARY_COLLECTION = 'TempTrans'
  
  FRIENDLY_NAME = "Inscription Translation"
  
  IDENTIFIER_NAMESPACE = 'epigraphy_translation'
  
  XML_VALIDATOR = JRubyXML::EpiDocP5Validator
   
  # defined in vendor/plugins/rxsugar/lib/jruby_helper.rb
  acts_as_translation

  
  def self.collection_names_hash
    self.collection_names
    
    unless defined? @collection_names_hash
      @collection_names_hash = {
        TEMPORARY_COLLECTION => "SoSOL Temporary Collection"}
      @collection_names_hash['epigraphy.perseus.org'] = "Perseus Epigraphy Collection"
    end
    
    return @collection_names_hash
  end
  
  def is_valid?(content = nil)
    #FIXME added here since trans is not P5 validable yet
    return true
  end
  
  def self.new_from_template(publication)
    new_identifier = super(publication)
    
    new_identifier.stub_text_structure('en')
    
    return new_identifier
  end
    
  def before_commit(content)
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt translation preprocess.xsl}))
    )
  end
  
  def translation_already_in_language?(lang)
    lang_path = '/TEI/text/body/div[@type = "translation" and @xml:lang = "' + lang + '"]'
    
    doc = REXML::Document.new(self.xml_content)
    result = REXML::XPath.match(doc, lang_path)
    
    if result.length > 0
     return true
    else
      return false
    end
     
  end
  
  def related_text
    self.publication.identifiers.select{|i| (i.class == EpiCTSIdentifier) && !i.is_reprinted?}.last
  end
  
  def stub_text_structure(lang)
    translation_stub_xsl =
      JRubyXML.apply_xsl_transform(
        JRubyXML.stream_from_string(self.related_text.content),
        JRubyXML.stream_from_file(File.join(RAILS_ROOT,
          %w{data xslt translation ddb_to_translation_xsl.xsl}))
      )
    
    rewritten_xml =
      JRubyXML.apply_xsl_transform(
        JRubyXML.stream_from_string(self.content),
        JRubyXML.stream_from_string(translation_stub_xsl),
        #:lang => 'en'
        #assumed that hard coded 'en' is remnant and should be
        :lang => lang
      )
      
    
    self.set_xml_content(rewritten_xml, :comment => "Update translation with stub for @xml:lang='#{lang}'")
  end
  
  def after_rename(options = {})
    if options[:update_header]
      rewritten_xml =
        JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(content),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
            %w{data xslt translation update_header.xsl})),
          :filename_text => self.to_components.last,
          :title_text => NumbersRDF::NumbersHelper::identifier_to_title([NumbersRDF::NAMESPACE_IDENTIFIER,CTSIdentifier::IDENTIFIER_NAMESPACE,self.to_components.last].join('/')),
          :reprint_from_text => options[:set_dummy_header] ? options[:original].title : '',
          :reprint_ref_attribute => options[:set_dummy_header] ? options[:original].to_components.last : ''
        )
    
      self.set_xml_content(rewritten_xml, :comment => "Update header to reflect new identifier '#{self.name}'")
    end
  end
  
  def preview
      JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(self.xml_content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt pn start-divtrans-portlet.xsl})))
  end
  
  def get_broken_leiden(original_xml = nil)
    original_xml_content = original_xml || REXML::Document.new(self.xml_content)
    brokeleiden_path = '/TEI/text/body/div[@type = "translation"]/div[@subtype = "brokeleiden"]/note'
    brokeleiden_here = REXML::XPath.first(original_xml_content, brokeleiden_path)
    if brokeleiden_here.nil?
      return nil
    else
      brokeleiden = brokeleiden_here.get_text.value
      
      return brokeleiden.sub(/^#{Regexp.escape(BROKE_LEIDEN_MESSAGE)}/,'')
    end
  end
  
  def leiden_trans
    original_xml = self.xml_content
    original_xml_content = REXML::Document.new(original_xml)

    # if XML does not contain broke Leiden send XML to be converted to Leiden and return that
    # otherwise, return nil (client can then get_broken_leiden)
    if get_broken_leiden(original_xml_content).nil?
      body = EpiTransCTSIdentifier.get_body(original_xml)
      
      # transform XML to Leiden+ 
      transformed = EpiTransCTSIdentifier.xml2nonxml(body.to_s) #via jrubyHelper
      
      return transformed
    else
      return nil
    end
  end
  
  # Returns a String of the SHA1 of the commit
  def set_leiden_translation_content(leiden_translation_content, comment)
    # transform back to XML
    xml_content = self.leiden_translation_to_xml(leiden_translation_content)
    # commit xml to repo
    self.set_xml_content(xml_content, :comment => comment)
  end
  
  
  def leiden_translation_to_xml(content)
    
    # transform the Leiden Translation to XML
    nonx2x = EpiTransCTSIdentifier.nonxml2xml(content)
        
    nonx2x.sub!(/ xmlns:xml="http:\/\/www.w3.org\/XML\/1998\/namespace"/,'')
    transformed_xml_content = REXML::Document.new(nonx2x)
    
    #puts nonx2x
    #puts transformed_xml_content.to_s
    # fetch the original content
    original_xml_content = REXML::Document.new(self.xml_content)
    
    #rip out the body so we can replace it with the new data
    original_xml_content.delete_element('/TEI/text/body')
    
    #add the new data
    original_xml_content.elements.each('/TEI/text') { |text_element| text_element.add_element(transformed_xml_content) }
    
 
    # write back to a string
    modified_xml_content = ''
    original_xml_content.write(modified_xml_content)
    return modified_xml_content
  end
  
  
  
  
  def save_broken_leiden_trans_to_xml(brokeleiden, commit_comment = '')
    # fetch the original content
    original_xml_content = REXML::Document.new(self.xml_content)
    #deletes XML with broke Leiden+ if it exists already so can add with updated data
    original_xml_content.delete_element('/TEI/text/body/div[@type = "translation"]/div[@subtype = "brokeleiden"]')
    #set in XML where to add new div tag to contain broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "translation"]'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    add_node_here.add_element 'div', {'type'=>'translation', 'subtype'=>'brokeleiden'}
    #set in XML where to add new note tag to contain broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "translation"]/div[@subtype = "brokeleiden"]'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    add_node_here.add_element "note"
    #set in XML where to add broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "translation"]/div[@subtype = "brokeleiden"]/note'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    brokeleiden = BROKE_LEIDEN_MESSAGE + brokeleiden
    add_node_here.add_text brokeleiden
    
    # write back to a string
    modified_xml_content = ''
    original_xml_content.write(modified_xml_content)
    
    # commit xml to repo
    self.set_xml_content(modified_xml_content, :comment => commit_comment)
  end
end
