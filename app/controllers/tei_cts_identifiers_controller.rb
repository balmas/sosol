class TeiCtsIdentifiersController < IdentifiersController
  layout 'site'
  before_filter :authorize
  
  ## TODO 
  # we to offer the following options:
  # 1. select a passage or passage-range to edit -> results in creation of one or more TeiPassageCTSIdentifier obj
  # 2. download/export full XML of outermost tei:text element [ maybe limited to a specific role? ]
  # 3. upload/import full XML of outermost tei:text element [ maybe limited to a specific role? ]
  # 3. edit/update commentary (teiHeader) 
  # 4. select a translation to edit ?
  # 5. add a CITE index 
  # 6. update a CITE index 
  
  # Ideally TeiPassageCTSIdentifier Interface would offer options to create stand-off markup in the form of
  # CITE index entries, for example:
  #    from within a select a range of XML to create an index entry from
  #    e.g. this range is a quotation, this range is a named entity, this range maps to image coordinates X 
  
  # so related identifier types would be:
  ## TeiPassageCTSIdentifier
  ## TeiTransCTSIdentifier
  ## CITEIndexIdentifier
  
  def edit
    find_identifier
    # Redirecting to Publication because don't want to immediately show them
    # the full XML - instead from Publication they can select a passage, etc.
    publication = @identifier.publication.id
     redirect_to polymorphic_path([@identifier.publication],
                                     :action => :show)
  end
  
  # GET /publications/1/tei_passage_cts_identifiers/1/edit
  def exportxml
    find_identifier
  end
  
  # PUT /publications/1/tei_passage_cts_identifiers/1/update
  def update
    find_identifier
    @original_commit_comment = ''
    #if user fills in comment box at top, it overrides the bottom
    if params[:commenttop] != nil && params[:commenttop].strip != ""
      params[:comment] = params[:commenttop]
    end
    begin
      commit_sha = @identifier.set_xml_content(params[:tei_cts_identifier],
                                    params[:comment])
      if params[:comment] != nil && params[:comment].strip != ""
          @comment = Comment.new( {:git_hash => commit_sha, :user_id => @current_user.id, :identifier_id => @identifier.origin.id, :publication_id => @identifier.publication.origin.id, :comment => params[:comment], :reason => "commit" } )
          @comment.save
      end
      flash[:notice] = "File updated."
      expire_publication_cache
      if %w{new editing}.include?@identifier.publication.status
          flash[:notice] += " Go to the <a href='#{url_for(@identifier.publication)}'>publication overview</a> if you would like to submit."
      end
        
      redirect_to polymorphic_path([@identifier.publication, @identifier],
                                     :action => :edit)
      rescue JRubyXML::ParseError => parse_error
        flash.now[:error] = parse_error.to_str + 
          ".  This message is because the XML did not pass Relax NG validation.  This file was NOT SAVED. "
        render :template => 'tei_cts_identifiers/edit'
      end #begin
  end
   
    
  # GET /publications/1/tei_passage_cts_identifiers/1/preview
  def preview
    find_identifier
    
    # Dir.chdir(File.join(RAILS_ROOT, 'data/xslt/'))
    # xslt = XML::XSLT.new()
    # xslt.xml = REXML::Document.ncew(@identifier.xml_content)
    # xslt.xsl = REXML::Document.new File.open('start-div-portlet.xsl')
    # xslt.serve()

    @identifier[:html_preview] = @identifier.preview
  end
  
  protected
    def find_identifier
      @identifier = TeiCTSIdentifier.find(params[:id])
    end
  
    def find_publication_and_identifier
      @publication = Publication.find(params[:publication_id])
      find_identifier
    end
end
