class CITEIdentifier < Identifier
  # This is a superclass for objects using CITE Identifiers, including
  # shared constants and methods. No instances of CITEIdentifier should be
  # created. 
  
  IDENTIFIER_PREFIX = 'urn:cite:'
  IDENTIFIER_NAMESPACE = ''
  NAMESPACE_DOMAIN = '.perseus.org'

  TEMPORARY_COLLECTION = 'TempCITE'

  FRIENDLY_NAME = "CITE Identifier"
  
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
  
  def id_attribute
    # real CITE urns should only have two parts collection and id
    # the temporary SoSOL created id will have 3, so we just join the last 2 parts with an _
    collection,id =
      self.to_components.last.split('.',2).collect{|i| i.tr('.','_')}
    
    return [IDENTIFIER_PREFIX,self.class::IDENTIFIER_NAMESPACE,NAMESPACE_DOMAIN].join('') +  ":" + [collection, id].reject{|i| i.blank?}.join('.')
  end
  
  def n_attribute
    cts = EpiCTSIdentifier.find_by_publication_id(self.publication.id, :limit => 1)
    return cts.n_attribute
  end
  
  
  def self.collection_names
    unless defined? @collection_names
      @collection_names = Array ["epi_meta.perseus.org"]
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
  
  def to_path
    path_components = [ self.class::PATH_PREFIX ]
    
    cite_collection, cite_id =
      self.to_components[1..-1].join('/').split('.')
      
    # switch commas to dashes
    cite_collection.tr!(',','-')
    cite_id.tr!(',','-')
    
    # switch forward slashes to underscores
    cite_collection.tr!('/','_')
    cite_id.tr!('/','_')
    
    cite_file_path_components = []
    cite_file_path_components << cite_collection
    cite_file_path_components << cite_id << self.class::CITE_FILE_EXTENSION
    cite_file_path = cite_file_path_components.join('.')
    
    path_components << cite_collection
    path_components << cite_id
    path_components << cite_file_path
    
    # e.g. CITE_OBJ/collectionx/objy.xml
    return File.join(path_components)
  end
end