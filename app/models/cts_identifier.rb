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
    unless defined? @collection_names
      @collection_names = Array ["epigraphy.perseus.org"]
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
  def id_attribute
     cts_textgroup, cts_work, cts_edition, cts_exemplar =
      self.to_components.last.split('.')
    
    
    return [IDENTIFIER_PREFIX,self.class::IDENTIFIER_NAMESPACE,NAMESPACE_DOMAIN].join('') + ':' + [cts_textgroup, cts_work, cts_edition, cts_exemplar].reject{|i| i.blank?}.join('.') 
  end
  
  def n_attribute
    return id_attribute
  end
  
  def xml_title_text
    # TODO lookup title
    self.id_attribute
  end
    
  def to_path
    path_components = [ self.class::PATH_PREFIX ]
    cts_textgroup,cts_work,cts_edition,cts_exemplar =
      self.to_components[1..-1].join('/').split('.',4).collect {|x| x.tr(',/','-_')}
    
    # e.g. igvii.2543-2545.perseus-grc1.xml
    cts_xml_path_components = []
    cts_xml_path_components << cts_textgroup
    unless cts_work.nil?
      cts_xml_path_components << cts_work
    end
    cts_xml_path_components << cts_edition 
    unless cts_exemplar.nil? 
      cts_xml_path_components << cts_exemplar 
    end
    cts_xml_path_components << 'xml' 
    cts_xml_path = cts_xml_path_components.join('.')
    
    path_components << cts_textgroup
    unless cts_work.nil?
      path_components << cts_work
    end
    path_components << cts_xml_path
    
    # e.g. CTS_EPI_XML/igvii/2543-2545/igvii.2543-2545.perseus-grc1.xml
    return File.join(self.class::PATH_PREFIX,path_components)
  end
end
