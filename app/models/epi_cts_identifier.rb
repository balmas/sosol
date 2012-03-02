class EpiCTSIdentifier < CTSIdentifier   
  
  PATH_PREFIX = 'CTS_XML_EpiDoc'
  COLLECTION_XML_PATH = 'CTS_INVENTORIES/epigraphy.xml'
  
  FRIENDLY_NAME = "Text"
  
  IDENTIFIER_NAMESPACE = 'epigraphy_edition'
  
  XML_VALIDATOR = JRubyXML::EpiDocP5Validator
  
  BROKE_LEIDEN_MESSAGE = "Broken Leiden+ below saved to come back to later:\n"
  
  # defined in vendor/plugins/rxsugar/lib/jruby_helper.rb
  acts_as_leiden_plus

  
  def self.collection_names_hash
    self.collection_names
    
    unless defined? @collection_names_hash
      @collection_names_hash = {
        TEMPORARY_COLLECTION => "SoSOL Temporary Collection"}
      @collection_names_hash['epigraphy.perseus.org'] = "Perseus Epigraphy Collection"
    end
    
    return @collection_names_hash
  end
  
    
  def before_commit(content)
    Rails.logger.info("Before commit content =" + content)
    EpiCTSIdentifier.preprocess(content)
  end
  
  def self.preprocess(content)
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt ddb preprocess.xsl})))
  end
  
  def after_rename(options = {})
    # copy back the content to the original name before we update the header
    if options[:set_dummy_header]
      original = options[:original]
      dummy_comment_text = "Add dummy header for original identifier '#{original.name}' pointing to new identifier '#{self.name}'"
      dummy_header =
        JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(content),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
            %w{data xslt ddb dummyize.xsl})),
          :reprint_in_text => self.title,
          :ddb_hybrid_ref_attribute => self.n_attribute
        )
      
      original.save!
      self.publication.identifiers << original
      
      dummy_header = self.add_change_desc(dummy_comment_text, self.publication.owner, dummy_header)
      original.set_xml_content(dummy_header, :comment => dummy_comment_text)
            
      # need to do on originals too
      self.relatives.each do |relative|
        original_relative = relative.clone
        original_relative.name = original.name
        original_relative.title = original.title
        relative.save!
        
        relative.publication.identifiers << original_relative
        
        # set the dummy header on the relative
        original_relative.set_xml_content(dummy_header, :comment => dummy_comment_text)
      end
    end
    
    if options[:update_header]
      rewritten_xml =
        JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(content),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
            %w{data xslt ddb update_header.xsl})),
          :title_text => self.xml_title_text,
          :human_title_text => self.titleize,
          :filename_text => self.urn_attribute,
          :ddb_hybrid_text => self.n_attribute,
          :reprint_from_text => options[:set_dummy_header] ? original.title : '',
          :ddb_hybrid_ref_attribute => options[:set_dummy_header] ? original.n_attribute : ''
        )
    
      self.set_xml_content(rewritten_xml, :comment => "Update header to reflect new identifier '#{self.name}'")
    end
  end
  
  def update_commentary(line_id, reference, comment_content = '', original_item_id = '', delete_comment = false)
    rewritten_xml =
      JRubyXML.apply_xsl_transform(
        JRubyXML.stream_from_string(
          EpiCTSIdentifier.preprocess(self.xml_content)),
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
          EpiCTSIdentifier.preprocess(self.xml_content)),
        JRubyXML.stream_from_file(File.join(RAILS_ROOT,
          %w{data xslt ddb update_frontmatter_commentary.xsl})),
        :content => commentary_content,
        :delete_commentary => (delete_commentary ? 'true' : '')
      )
    
    self.set_xml_content(rewritten_xml, :comment => '')
  end
  
  def get_broken_leiden(original_xml = nil)
    original_xml_content = original_xml || REXML::Document.new(self.xml_content)
    brokeleiden_path = '/TEI/text/body/div[@type = "edition"]/div[@subtype = "brokeleiden"]/note'
    brokeleiden_here = REXML::XPath.first(original_xml_content, brokeleiden_path)
    if brokeleiden_here.nil?
      return nil
    else
      brokeleiden = brokeleiden_here.get_text.value
      
      return brokeleiden.sub(/^#{Regexp.escape(BROKE_LEIDEN_MESSAGE)}/,'')
    end
  end
  
  def leiden_plus
    original_xml = EpiCTSIdentifier.preprocess(self.xml_content)
    
    # strip xml:id from lb's
    original_xml = JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(original_xml),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        %w{data xslt ddb strip_lb_ids.xsl})))
    
    original_xml_content = REXML::Document.new(original_xml)

    # if XML does not contain broke Leiden+ send XML to be converted to Leiden+ and return that
    # otherwise, return nil (client can then get_broken_leiden)
    if get_broken_leiden(original_xml_content).nil?
      # get div type=edition from XML in string format for conversion
      abs = EpiCTSIdentifier.get_div_edition(original_xml).to_s
      # transform XML to Leiden+ 
      transformed = EpiCTSIdentifier.xml2nonxml(abs)
      
      return transformed
    else
      return nil
    end
  end
  
  # Returns a String of the SHA1 of the commit
  def set_leiden_plus(leiden_plus_content, comment)
    
    pp_leiden = preprocess_leiden(leiden_plus_content)
    
    # transform back to XML
    xml_content = self.leiden_plus_to_xml(
      pp_leiden)
    # commit xml to repo
    self.set_xml_content(xml_content, :comment => comment)
  end
  
  def reprinted_in
    return REXML::XPath.first(REXML::Document.new(self.xml_content),
      "/TEI/text/body/head/ref[@type='reprint-in']/@n")
  end
  
  def is_reprinted?
    return reprinted_in.nil? ? false : true
  end
  
  # Override REXML::Attribute#to_string so that attributes are defined
  # with double quotes instead of single quotes
  REXML::Attribute.class_eval( %q^
    def to_string
      %Q[#@expanded_name="#{to_s().gsub(/"/, '&quot;')}"]
    end
  ^ )
  
  def leiden_plus_to_xml(content)

    Rails.logger.info("In leiden_plus_to_xml with " +content)
    # transform the Leiden+ to XML
    nonx2x = EpiCTSIdentifier.nonxml2xml(content)
    
    #remove namespace from XML returned from XSugar
    nonx2x.sub!(/ xmlns:xml="http:\/\/www.w3.org\/XML\/1998\/namespace"/,'')
      
    transformed_xml_content = REXML::Document.new(
      nonx2x)
      
    # fetch the original content
    original_xml_content = REXML::Document.new(self.xml_content)
    
    #deletes div type=edition in current XML which includes <div> with subtype=brokeLeiden if it exists, 
    #all <div> type=textpart and/or <ab> tags
    #the complete <div> type=edition will be replaced with new transformed_xml_content
    original_xml_content.delete_element('/TEI/text/body/div[@type = "edition"]')
    
    #delete \n left after delete div edition so not keep adding newlines to XML content
    original_xml_content.delete_element('/TEI/text/body/node()[last()]')
    
    modified_abs = transformed_xml_content.elements['/']
    
    original_edition =  original_xml_content.elements['/TEI/text/body']
    
    # put new div type=edition content in
    original_edition.add_text modified_abs[0]
    
    # write back to a string and return it to calling 
    modified_xml_content = ''
    original_xml_content.write(modified_xml_content)
    return modified_xml_content
  end
  
  def save_broken_leiden_plus_to_xml(brokeleiden, commit_comment = '')
    # fetch the original content
    original_xml_content = REXML::Document.new(self.xml_content)
    #deletes XML with broke Leiden+ if it exists already so can add with updated data
    original_xml_content.delete_element('/TEI/text/body/div[@type = "edition"]/div[@subtype = "brokeleiden"]')
    #set in XML where to add new div tag to contain broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "edition"]'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    add_node_here.add_element 'div', {'type'=>'edition', 'subtype'=>'brokeleiden'}
    #set in XML where to add new note tag to contain broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "edition"]/div[@subtype = "brokeleiden"]'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    add_node_here.add_element "note"
    #set in XML where to add broken Leiden+ and add it
    basepath = '/TEI/text/body/div[@type = "edition"]/div[@subtype = "brokeleiden"]/note'
    add_node_here = REXML::XPath.first(original_xml_content, basepath)
    brokeleiden = BROKE_LEIDEN_MESSAGE + brokeleiden
    add_node_here.add_text brokeleiden
    
    # write back to a string
    modified_xml_content = ''
    original_xml_content.write(modified_xml_content)
    
    # commit xml to repo
    self.set_xml_content(modified_xml_content, :comment => commit_comment)
  end

  def preview parameters = {}, xsl = nil
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(self.xml_content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        xsl ? xsl : %w{data xslt pn start-div-portlet_perseus.xsl})),
        parameters)
  end
  
  def preprocess_leiden(preprocessed_leiden)
    # mass substitute alternate keyboard characters for Leiden+ grammar characters

    # strip tabs
    preprocessed_leiden.tr!("\t",'')
    
    # consistent LT symbol (<)
    # \u2039 \u2329 \u27e8 \u3008 to \u003c')
    preprocessed_leiden.gsub!(/[‹〈⟨〈]{1}/,'<')
    
    # consistent GT symbol (>)
    # \u203a \u232a \u27e9 \u3009 to \u003e')
    preprocessed_leiden.gsub!(/[›〉⟩〉]{1}/,'>')
    
    # consistent Left square bracket (〚)
    # \u27e6 to \u301a')
    preprocessed_leiden.gsub!(/⟦/,'〚')
    
    # consistent Right square bracket (〛)
    # \u27e7 to \u301b')
    preprocessed_leiden.gsub!(/⟧/,'〛')
    
    # consistent macron (¯)
    # \u02c9 to \u00af')
    preprocessed_leiden.gsub!(/ˉ/,'¯')
    
    # consistent hyphen in linenumbers (-)
    # immediately preceded by a period 
    # \u2010 \u2011 \u2012 \u2013 \u2212 \u10191 to \u002d')
    preprocessed_leiden.gsub!(/\.{1}[‐‑‒–−𐆑]{1}/,'.-')
    
    # consistent hyphen in gap ranges (-)
    # between 2 numbers 
    # \u2010 \u2011 \u2012 \u2013 \u2212 \u10191 to \u002d')
    preprocessed_leiden.gsub!(/(\d+)([‐‑‒–−𐆑]{1})(\d+)/,'\1-\3')
    
    return preprocessed_leiden
  end
end
