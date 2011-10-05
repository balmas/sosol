class EpiMetaCITEIdentifier < CITEIdentifier
  attr_accessor :configuration, :valid_epidoc_attributes

  PATH_PREFIX = 'CITE_meta_EpiDoc'
  IDENTIFIER_NAMESPACE = 'epimeta'
  CITE_FILE_EXTENSION = 'xml'
  
  XML_VALIDATOR = JRubyXML::EpiDocP5Validator
  
  FRIENDLY_NAME = "EpiMeta"

  def preview parameters = {}, xsl = nil
    JRubyXML.apply_xsl_transform(
      JRubyXML.stream_from_string(self.xml_content),
      JRubyXML.stream_from_file(File.join(RAILS_ROOT,
        xsl ? xsl : %w{data xslt epidoc start-edition.xsl})),
        parameters)
  end

  def after_initialize
    @configuration = EpiMetaCITEConfiguration.new 
    @valid_epidoc_attributes = @configuration.keys
  end
  
  def xml_title_text
    return "Description of document"
  end

  def get_date_item date_id    
    self[:textDate].each{|dateItem|
      if dateItem[:attributes] && dateItem[:attributes][:id] && dateItem[:attributes][:id].include?(date_id)
        return dateItem
      elsif date_id.include?('X') && self[:textDate].first == dateItem
        return dateItem
      end
    }
    return nil    
  end

  # retrieve matadata from xml and store as object attributes
  #   e.g. title: <title>Instruction to track down murderers</title> will become
  #   self[:title] = 'Instruction to track down murderers'
  #   e.g. content text: <keywords><term>a</term><term>b</term></keywords> will become
  #   self[:contentText] = ['a', 'b']
  #   e.g. date will become complicated
  #

  def get_epidoc_attributes
    doc = REXML::Document.new self.content

    @configuration.scheme.each_pair do |key, config|
      if config[:children] || config[:attributes]
        self[key] = get_epidoc_attributes_tree doc, config
      elsif config[:multiple]
        self[key] = get_epidoc_attributes_list doc, config
      else 
        self[key] = get_epidoc_attributes_value doc, config
      end
    end
  end

  def get_epidoc_attributes_list doc, config
    list = []
    doc.elements.each(config[:xpath]){|element|
      if element.text && !element.text.strip.empty?
        list << element.text.strip
      end
    }
    list
  end

  def get_epidoc_attributes_tree doc, config
    tree = []
    
    doc.elements.each(config[:xpath]){|element|
      node = {:value => '', :attributes => {}, :children => {}}

      if config[:preFlag] && element.previous_element && config[:preFlag] == element.previous_element.name # CL: CROMULENT GEO HACK
        node[:preFlag] = 'bei';
      end

      if element.name.to_s == 'origDate' # CL: CROMULENT DATE HACK
        node[:value] = element.to_s.gsub(/[\s]+/, ' ').gsub(/<\/?[^>]*>/, "").strip
      elsif element.text && !element.text.strip.empty?
        node[:value] = element.text.strip
      else
        node[:value] = config[:default]
      end

      if config[:attributes]
        config[:attributes].each_pair{|attribute_key, attribute_config|
          node[:attributes][attribute_key] = element.attributes[attribute_config[:name]] && !element.attributes[attribute_config[:name]].strip.empty? ? element.attributes[attribute_config[:name]].strip : attribute_config[:default]
        }
      end

      if config[:children]
        config[:children].each_pair{|child_key, child_config|
          node[:children][child_key] = get_epidoc_attributes_tree element, child_config
        }
      end
      
      tree[tree.length] = node
    }

    return config[:multiple] ? tree : tree.first
  end

  def get_epidoc_attributes_value doc, config
    if element = doc.elements[config[:xpath]]
      element.text && !element.text.strip.empty? ? element.text.strip : config[:default]
    else
      config[:default]
    end
  end

  # Returns a String of the SHA1 of the commit
  def set_epidoc(attributes_hash, comment)
    populate_epidoc_attributes_from_attributes_hash(attributes_hash)

    epidoc = set_epidoc_attributes

    #File.open('/Users/InstPap/Desktop/sosoltest.xml', 'w') {|f| f.write(epidoc) }

    #set_content does not validate xml (which is what epidoc is)
    #self.set_content(epidoc, :comment => comment)
    #set_xml_content validates xml
    self.set_xml_content(epidoc, :comment => comment)
  end

  def after_rename(options = {})
    if options[:update_header]
      rewritten_xml =
        JRubyXML.apply_xsl_transform(
          JRubyXML.stream_from_string(content),
          JRubyXML.stream_from_file(File.join(RAILS_ROOT,
            %w{data xslt metadata update_header.xsl})),
          :filename_text => self.to_components.last,
          :reprint_from_text => options[:set_dummy_header] ? options[:original].title : '',
          :reprent_ref_attirbute => options[:set_dummy_header] ? options[:original].to_components.last : ''
        )
      self.set_xml_content(rewritten_xml, :comment => "Update header to reflect new identifier '#{self.name}'")
    end
  end

  # saves the values stored within a hash object (usually generated via a webbrowser form)
  def populate_epidoc_attributes_from_attributes_hash attributes_hash

    @configuration.scheme.each_pair do |key, config|
      if config[:children] || config[:attributes]
        result = if config[:multiple]
          tmp = []
          if attributes_hash[key.to_s]
            attributes_hash[key.to_s].each_pair {|index, item|
              tmp[tmp.length] = populate_tree_from_attributes_hash item, config
            }
          end
          tmp
        else
          populate_tree_from_attributes_hash attributes_hash[key.to_s], config      
        end

        self[key] = result  
      elsif config[:multiple]
        self[key] = attributes_hash[key.to_s] ? attributes_hash[key.to_s].values.compact.reject {|item| item.strip.empty? }.collect{|item| item.strip } : []
      else 
        self[key] = attributes_hash[key.to_s] ? attributes_hash[key.to_s].strip : nil
      end
    end
  end


  protected

=begin

:contentText => [
  'x',
  'y',
  'z',
  ...
]

:bl => [
  {:value => nil, :children => {}, :attributes =>{}},
  {:value => nil, :children => {}, :attributes =>{}},
  {:value => nil, :children => {}, :attributes =>{}},
  ...
]

=end

  def set_epidoc_attributes_tree parent, xpath, data, config
    child_name = xpath[/\A([\w]+)[\w\/\[\]@:=']*\Z/, 1]
    child_attributes = xpath.scan /@([\w:]+)='([\w]+)'/

    index = 1
    data.each { |item|

      hasContent = (item.class == String) ? (item.strip.empty? ? false : true) : (item[:value] && !item[:value].strip.empty? ? true : (item[:attributes] && !item[:attributes].values.join.empty? ? true : (!item[:children].empty? ? true : false)))

      if hasContent

        child = REXML::Element.new child_name
        child_attributes.each{|name, value|
          child.attributes[name] = value
        }
        if data.length > 1
          child.attributes['n'] = index.to_s
          index += 1
        end
  
        if item.class == String && !item.strip.empty?
          child.text = item.strip
        else
          if item[:value] && !item[:value].strip.empty?
            child.text = item[:value].strip
          end

          if config[:attributes]
            config[:attributes].each_pair{|attribute_key, attribute_config|
               if item[:attributes] && item[:attributes][attribute_key] && !item[:attributes][attribute_key].strip.empty?
                 child.attributes[attribute_config[:name]] = item[:attributes][attribute_key].strip
               elsif attribute_config[:default]
                 child.attributes[attribute_config[:name]] = attribute_config[:default]
               end
            }
          end

          if config[:children] && item[:children]
            config[:children].each_pair{|grandchild_name, grandchild_config|
              if item[:children][grandchild_name]
                grandchild_data = item[:children][grandchild_name].class == Array ? item[:children][grandchild_name] : [item[:children][grandchild_name]]
                grandchild_xpath = grandchild_config[:xpath]
                set_epidoc_attributes_tree child, grandchild_xpath, grandchild_data, grandchild_config # recursion
              end
            }
          end
        end

        
        if item[:preFlag] # CL: CROMULENT GEO HACK
          offset = REXML::Element.new 'offset'
          offset.add_text 'bei'
          parent.add offset
        end
        
        parent.add child

      end
    }
  end

  def set_epidoc_attributes
    # load xml document
    doc = REXML::Document.new self.content

    @configuration.scheme.each_pair do |key, config|
      xpath_parent = config[:xpath][/\A([\w\/\[\]@:=']+)\/([\w\/\[\]@:=']+)\Z/, 1]
      xpath_child = $2 
      if config[:multiple]

        if self[key].empty?
          if parent = doc.elements[xpath_parent]
            parent.elements.delete_all xpath_child
            if !parent.has_elements? && parent.texts.join.strip.empty?
              parent.elements['..'].delete parent
            end
          end
        else
          if parent = doc.elements[xpath_parent]
            parent.elements.delete_all xpath_child
          else
            parent = doc.bulldozePath xpath_parent
          end

          set_epidoc_attributes_tree parent, xpath_child, self[key], config
        end

      else
        value = self[key] && !self[key].empty? ? (config[:children] || config[:attributes] ? self[key][:value] : self[key]) : nil
        
        if value && !value.empty? # CL: Biblio here!
          element = doc.bulldozePath(config[:xpath])
          element.text = value
          if config[:attributes]
            config[:attributes].each_pair {|attribute_key, attribute_config|
              element.attributes[attribute_config[:name]] = self[key][:attributes][attribute_key] #self[attribute_key]
            }
          end
          
        else

          doc.elements.delete_all config[:xpath]
          if parent = doc.elements[xpath_parent]
            if !parent.has_elements? && parent.texts.join.strip.empty?
              parent.elements['..'].delete parent
            end
          end
        end

      end

    end

    # sort
    doc = sort doc

    # write back to a string
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.width = 512
    modified_xml_content = ''
    formatter.write doc, modified_xml_content

    return modified_xml_content
  end

  def sort doc
    # general
    sort_paths = {
      :msIdentifier => {
        :parent => '/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msIdentifier',
        :children => ['placename', 'collection', 'idno', 'altIdentifier']
      },
      :altIdentifier => {
        :parent => "/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msIdentifier/altIdentifier[@type='temporary']",
        :children => ['placename', 'collection', 'idno', 'note']
      }
    }

    sort_paths.each_value {|sort_path|
    
      if parent = doc.elements[sort_path[:parent]]
        sort_path[:children].each {|child_path|
          parent.elements.each(child_path){|child|
            parent.delete child
            parent.add child
          }
        }
      end
    }
    
    # date

    doc.elements.each(@configuration.scheme[:textDate][:xpath]){|date|
      if date.elements['offset']

        hgvFormat = ''
        date.texts.each{|text|
          hgvFormat += text.value
          date.delete text  
        }
        hgvFormat = hgvFormat.gsub(/(vor|nach)( \(\?\))?/, '').strip
        
        offset = date.elements['offset[position()=1]']
        offset2 = date.elements['offset[position()=2]']
        
        date.delete offset
        date.delete offset2        
        
        if offset
          date.add_element offset
          date.add_text REXML::Text.new(' ')
        end
        
        if hgvFormat.include? ' - '
          hgvFormat = hgvFormat.split ' - '
          date.add_text REXML::Text.new(hgvFormat[0] + ' - ')
          if offset2
            date.add_element offset2
            date.add_text REXML::Text.new(' ')
          end
          date.add_text REXML::Text.new(hgvFormat[1])
        else
          date.add_text REXML::Text.new(hgvFormat)
        end

      end
    }

   return doc 
  end

  def populate_epidoc_attribute key, value, default = nil
    if !value
      value = default
    elsif value.instance_of? String
      value = !value.strip.empty? ? value.strip : default
    elsif value.class == Array
      value = value.compact.reject {|item| item.strip.empty? }.collect{|item| item.strip }
    elsif value.kind_of? Hash
      value = value.values.compact.reject {|item| item.strip.empty? }.collect{|item| item.strip }
    end
    self[key] = value    
  end

  def populate_tree_from_attributes_hash data, config

    result_item = {
      :value => nil,
      :attributes => {},
      :children => {}
    }

    if data

      if data['value'] && !data['value'].to_s.strip.empty?
        result_item[:value] = data['value'].to_s.strip
      elsif config[:default]
        result_item[:value] = config[:default]
      end

      if config[:attributes]
        config[:attributes].each_pair{|attribute_key, attribute_config|
          if data['attributes'] && data['attributes'][attribute_key.to_s] && !data['attributes'][attribute_key.to_s].to_s.strip.empty?
            result_item[:attributes][attribute_key] = data['attributes'][attribute_key.to_s].to_s.strip
          elsif attribute_config[:default]
            result_item[:attributes][attribute_key] = attribute_config[:default]
          end
        }
      end

      if config[:children]
        config[:children].each_pair{|child_key, child_config|
          if child_config[:multiple]
            children = []
            
            if data[:children]
              x = data[:children][child_key.to_s].kind_of?(Hash) ? data[:children][child_key.to_s].values : data[:children][child_key.to_s]
              
              x.each{|child|
                children[children.length] = populate_tree_from_attributes_hash child, child_config # recursion óla
              }
            end
            result_item[:children][child_key] = children
          else
            result_item[:children][child_key] = populate_tree_from_attributes_hash  data['children'][child_key.to_s], child_config # recursion óla
          end
        }
      end
      
      if config[:preFlag] and data[:children][:offset][:value] and  data[:children][:offset][:value] == 'bei' # CL: CROMULENT GEO HACK
        result_item[:preFlag] = 'bei'
      end

   end

   result_item
  end

  class EpiMetaCITEConfiguration

    attr_reader :scheme, :keys;

    def initialize
      @scheme = YAML::load_file(File.join(RAILS_ROOT, %w{config epimetacite.yml}))[:epi][:metadata]

      add_meta_information! @scheme

      @keys = @scheme.keys
      @scheme.each_value {|item|
        @keys += retrieve_all_keys item
      }
  
    end

    # recursivle retrieves all valid keys (element key, attribute keys, child keys)
    # configuration is a single element node of the hgv configuration
    def retrieve_all_keys configuration_node
      keys = configuration_node[:attributes] ? configuration_node[:attributes].keys : []
      if configuration_node[:children]
        configuration_node[:children].each_pair {|key, value|
          keys += [key]
          keys += retrieve_all_keys value
        }
      end
      return keys
    end

    # recursively adds optional attributes to configuration
    # parameter configuration is initially the complete hgv configuration, during recursion it contains the content of the children attribute
    def add_meta_information! configuration
      configuration.each_value {|element|

        add_defaults! element

        if element.keys.include? :attributes
          element[:attributes].each_value{|attribute|
            add_defaults! attribute
          }
        end

        if element.keys.include? :children
          add_meta_information! element[:children]
        end

      }
    end

    # adds optional attributes (suchs as mulplicity or default value) to a configuration item
    # parameter item may be an element or an attribute
    def add_defaults! item
      if item.keys.include? :multiple
        item[:multiple] = item[:multiple] ? true : false
      else
        item[:multiple] = false
      end

      if item.keys.include? :optional
          item[:optional] = !item[:optional] ? false : true
      else
        item[:optional] = true
      end

      if !item.keys.include? :default
        item[:default] = nil
      end

      if !item.keys.include? :pattern
        item[:pattern] = nil
      end

      #if item.keys.include? :children
      #  item[:structure] = :recursive
      #elsif item[:multiple]
      #  item[:structure] = :multiple
      #else
      #  item[:structure] = :simple
      #end
    end

    def xpath key
      if @scheme.keys.include? key
        @scheme[key][:xpath]
      else
        ''
      end
    end

  end
end
