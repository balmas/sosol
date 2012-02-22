class PassageCtsIdentifiersController < IdentifiersController
  layout 'site'
  before_filter :authorize
  
  # GET /publications/1/passage_cts_identifiers/1/edit
  def edit
    redirect_to :action =>"editxml",:id=>params[:id]
  end
  
  # present valid passage refs
  def create
    if (! params[:passage] || params[:passage].strip == "")
      flash[:notice] = "Supply a valid passage range"
      render :template => 'passage_cts_identifiers/create'
      return
    else
      publication_identifier = params[:publication_id]
      @publication = Publication.find(params[:publication_id])
      passage_identifier = PassageCTSIdentifier.get_passage_identifier(@publication,params[:passage])    
      conflicts = []  
      for pubid in @publication.identifiers do 
        if pubid.name == passage_identifier
          conflicts << pubid
        end
      end 
      
      if conflicts.length >0        
        conflicting_passage = Publication.find(conflicts.first)
        flash[:error] = "Error creating passage: passage already exists. Please delete the <a href='#{url_for(conflicting_passage)}'>conflicting publication</a> if you have not submitted it and would like to start from scratch."
        redirect_to dashboard_url
        return
      end
      
      @identifier = PassageCTSIdentifier.new_from_template(@publication,passage_identifier)
      flash[:notice] = "File created."
      expire_publication_cache
      redirect_to polymorphic_path([@identifier.publication, @identifier],
                                 :action => :editxml) and return
    end                      
  end
  
  # PUT /publications/1/passage_cts_identifiers/1/update
  def update
    find_identifier
    @original_commit_comment = ''
    #if user fills in comment box at top, it overrides the bottom
    if params[:commenttop] != nil && params[:commenttop].strip != ""
      params[:comment] = params[:commenttop]
    end
    begin
      commit_sha = @identifier.set_xml_content(params[:passage_cts_identifier],
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
                                     :action => :editxml)
      rescue JRubyXML::ParseError => parse_error
        flash.now[:error] = parse_error.to_str + 
          ".  This message is because the XML did not pass Relax NG validation.  This file was NOT SAVED. "
        render :template => 'passage_cts_identifiers/edit'
      end #begin
  end
   
    
  # GET /publications/1/passage_cts_identifiers/1/preview
  def preview
    find_identifier
    
    # Dir.chdir(File.join(RAILS_ROOT, 'data/xslt/'))
    # xslt = XML::XSLT.new()
    # xslt.xml = REXML::Document.new(@identifier.xml_content)
    # xslt.xsl = REXML::Document.new File.open('start-div-portlet.xsl')
    # xslt.serve()

    @identifier[:html_preview] = @identifier.preview
  end
  
  protected
    def find_identifier
      @identifier = PassageCTSIdentifier.find(params[:id])
    end
  
    def find_publication_and_identifier
      @publication = Publication.find(params[:publication_id])
      find_identifier
    end
end
