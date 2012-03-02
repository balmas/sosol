class CTSIdentifier < Identifier  
  # This is a superclass for objects using CITE Identifiers, including
  # shared constants and methods. No instances of CITEIdentifier should be
  # created. 
  COLLECTION_XML_PATH = 'CTS_INVENTORIES/inventory.xml'
  FRIENDLY_NAME = "Text"
  
  IDENTIFIER_PREFIX = 'urn:cts:' 
  IDENTIFIER_NAMESPACE = ''
  NAMESPACE_DOMAIN = '.perseus.org'
  TEMPORARY_COLLECTION = 'TempTexts'
  
  def self.inventories_hash
    return CTS::CTSLib.getInventoriesHash()
  end
  
  def self.next_temporary_identifier
    year = Time.now.year
    latest = self.find(:all,
                       :conditions => ["name like ?", "#{self::IDENTIFIER_NAMESPACE}#{self::NAMESPACE_DOMAIN}/#{self::TEMPORARY_COLLECTION}.#{year}.%"],
                       :order => "name DESC",
                       :limit => 1).first
    if latest.nil?
      # no constructed id's for this year/class
      document_number = 1
    else
      Rails.logger.info("------Last component" + latest.to_components.last.split(/[\.;]/).last )
      document_number = latest.to_components.last.split(/[\.;]/).last.to_i + 1
    end
    
    return sprintf("#{self::IDENTIFIER_NAMESPACE}#{self::NAMESPACE_DOMAIN}/#{self::TEMPORARY_COLLECTION}.%04d.%04d",
                   year, document_number)
  end
  
  def self.collection_names
    # to do - pull from CTS inventory
    unless defined? @collection_names
      @collection_names = Array ["epigraphy.perseus.org","greekLang","latinLang"]
    end
    return @collection_names
  end
  
  def self.collection_names_hash
    self.collection_names
    
    unless defined? @collection_names_hash
      @collection_names_hash = {TEMPORARY_COLLECTION => TEMPORARY_COLLECTION}
      @collection_names.each do |collection_name|
        human_name = collection_name.tr('_',' ')
        @collection_names_hash[collection_name] = human_name
      end
    end
    
    return @collection_names_hash
  end
  
  def urn_attribute
     return IDENTIFIER_PREFIX + self.to_urn_components.join(":")
  end
  
  def id_attribute
     return (IDENTIFIER_PREFIX + self.to_urn_components.join("_")).gsub!(/:/,'_')
  end
  
  def n_attribute
    return id_attribute
  end
  
  def xml_title_text
    # TODO lookup title
    self.urn_attribute
  end
    
  def to_urn_components
    temp_components = self.to_components
    # should give us, e.g.
    # [0] greekLang - namespace
    # [1] tlg0012.tlg001 - work
    # [2] edition or translation
    # [3] perseus-grc1 - edition + examplar
    # [4] 1.1 - passage
    Rails.logger.info(temp_components.inspect)
    urn_components = []
    urn_components << temp_components[0]
    urn_components << [temp_components[1],temp_components[3]].join(".")
    unless temp_components[4].nil? 
      urn_components << temp_components[4] 
    end
    return urn_components
  end
  
  def to_path
    path_components = [ self.class::PATH_PREFIX ]
    temp_components = self.to_components
    Rails.logger.info("PATH:" + temp_components.inspect)
    # should give us, e.g.
    # [0] greekLang - namespace
    # [1] tlg0012.tlg001 - work
    # [2] edition or translation
    # [3] perseus-grc1 - edition + examplar
    # [4] 1.1 - passage
    cts_ns = temp_components[0]
    cts_urn = temp_components[1] + "." + temp_components[3]
    cts_passage = temp_components[4]
    
    cts_textgroup,cts_work,cts_edition,cts_exemplar, =
      cts_urn.split('.',4).collect {|x| x.tr(',/','-_')}
    
    # e.g. tlg0012.tlg001.perseus-grc1.1.1.xml
    cts_xml_path_components = []
    cts_xml_path_components << cts_textgroup
    unless cts_work.nil?
      cts_xml_path_components << cts_work
    end
    cts_xml_path_components << cts_edition 
    unless cts_exemplar.nil? 
      cts_xml_path_components << cts_exemplar 
    end
    unless cts_passage.nil? 
      cts_xml_path_components << cts_passage 
    end
    cts_xml_path_components << 'xml' 
    cts_xml_path = cts_xml_path_components.join('.')
    
    path_components << cts_ns
    path_components << cts_textgroup
    unless cts_work.nil?
      path_components << cts_work
    end
    path_components << cts_xml_path
    
    # e.g. CTS_XML_PASSAGES/greekLang/tlg0012/tlg001/tlg0012.tlg001.perseus-grc1.1.1.xml
    return File.join(path_components)
  end
end
