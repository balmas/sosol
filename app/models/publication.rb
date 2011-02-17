class Publication < ActiveRecord::Base  
    
  
  PUBLICATION_STATUS = %w{ new editing submitted approved finalizing committed archived }
  
  validates_presence_of :title, :branch
  
  belongs_to :creator, :polymorphic => true
  belongs_to :owner, :polymorphic => true
  
  has_many :children, :class_name => 'Publication', :foreign_key => 'parent_id'
  belongs_to :parent, :class_name => 'Publication'
  
  has_many :identifiers, :dependent => :destroy
  has_many :events, :as => :target, :dependent => :destroy
 # has_many :votes, :dependent => :destroy
  has_many :comments
  
  validates_uniqueness_of :title, :scope => [:owner_type, :owner_id, :status]
  validates_uniqueness_of :branch, :scope => [:owner_type, :owner_id]

  validates_each :branch do |model, attr, value|
    # Excerpted from git/refs.c:
    # Make sure "ref" is something reasonable to have under ".git/refs/";
    # We do not like it if:
    if value =~ /^\./ ||    # - any path component of it begins with ".", or
       value =~ /\.\./ ||   # - it has double dots "..", or
       value =~ /[~^: ]/ || # - it has [..], "~", "^", ":" or SP, anywhere, or
       value =~ /\/$/ ||    # - it ends with a "/".
       value =~ /\.lock$/   # - it ends with ".lock"
      model.errors.add(attr, "Branch \"#{value}\" contains illegal characters")
    end
    # not yet handling ASCII control characters
  end
  
  named_scope :other_users, lambda{ |title, id| {:conditions => [ "title = ? AND creator_id != ? AND status = 'editing'", title, id] }        }
  
  #inelegant way to pass this info, but it works
  attr_accessor :recent_submit_sha

  def print
    # get preview of each identifier
    tmp = {}
    identifiers.each{|identifier|
      tmp[identifier.class.to_s.to_sym] = identifier.preview({'meta-style' => 'sammelbuch', 'leiden-style' => 'ddbdp'}, %w{data xslt epidoc start-odf.xsl})
    }

    Rails.logger.info('---------------DDB xml ---------------------')

    Rails.logger.info tmp[:DDBIdentifier].to_s

    Rails.logger.info('------------------------------------')

    #merge xml
    meta = REXML::Document.new tmp[:HGVMetaIdentifier]
    text = REXML::Document.new tmp[:DDBIdentifier]

    Rails.logger.info('---------------DDB xml document---------------------')

    Rails.logger.info text.elements["//office:document-content/office:body/office:text"].to_s
    
    Rails.logger.info('------------------------------------')

    elder = meta.elements["//office:document-content/office:body/office:text/text:p[@text:style-name='Sammelbuch-Kopf']"]
    text.elements["//office:document-content/office:body/office:text"].each_element {|text_element|

    Rails.logger.info('**** found['+text_element.class.inspect+']')

      meta.elements["//office:document-content/office:body/office:text"].insert_after(elder, text_element)
      elder = text_element

    }
    
    # output string
    formatter = REXML::Formatters::Default.new
    #formatter.compact = true
    #formatter.width = 512
    xml = ''
    formatter.write meta, xml

    xml
  end

  #Populates the publication's list of identifiers.
  #Input identifiers can be in the form of
  # * an array of strings such as: papyri.info/ddbdp/bgu;7;1504
  # * a single string such as: papyri.info/ddbdp/bgu;7;1504
  #publication title is named using first identifier
  def populate_identifiers_from_identifiers(identifiers)

    self.repository.update_master_from_canonical
    # Coming in from an identifier, build up a publication
    if identifiers.class == String
      # have a string, need to build relation
      identifiers = NumbersRDF::NumbersHelper.identifier_to_identifiers(identifiers)
    end

    #identifiers is now an array ofstrings like:  papyri.info/ddbdp/bgu;7;1504
    identifiers = NumbersRDF::NumbersHelper.identifiers_to_hash(identifiers)
    #identifiers is now a hash with IDENTIFIER_NAMESPACE (hgv, tm, ddbdp etc)  as the keys and the string papyri.info/ddbdp/bgu;7;1504 as the value


    #title is first identifier in list
    original_title = identifier_to_ref(identifiers.values.flatten.first)
    self.title = original_title

    [DDBIdentifier, HGVMetaIdentifier, HGVTransIdentifier].each do |identifier_class|
      if identifiers.has_key?(identifier_class::IDENTIFIER_NAMESPACE)
        identifiers[identifier_class::IDENTIFIER_NAMESPACE].each do |identifier_string|
          temp_id = identifier_class.new(:name => identifier_string)
          # make sure we have a path on master before forking it for this publication
          unless self.repository.get_file_from_branch(temp_id.to_path, 'master').blank?
            self.identifiers << temp_id
            if self.title == original_title
              self.title = temp_id.titleize
            end
          end
        end
      end
    end
    
    # Use HGV hack for now
    # if identifiers.has_key?('hgv') && identifiers.has_key?('trismegistos')
    #   identifiers['trismegistos'].each do |tm|
    #     tm_nr = NumbersRDF::NumbersHelper.identifier_to_components(tm).last
    #     self.identifiers << HGVMetaIdentifier.new(
    #       :name => "#{identifiers['hgv'].first}",
    #       :alternate_name => "hgv#{tm_nr}")
    #     
    #     # Check if there's a trans, if so, add it
    #     translation = HGVTransIdentifier.new(
    #       :name => "#{identifiers['hgv'].first}",
    #       :alternate_name => "hgv#{tm_nr}"
    #     )
    #     if !(Repository.new.get_file_from_branch(translation.to_path).nil?)
    #       self.identifiers << translation
    #     end
    #   end
    # end
  end
  
  # If branch hasn't been specified, create it from the title before
  # validation, replacing spaces with underscore.
  # TODO: do a branch rename inside before_validation_on_update?
  def before_validation
    self.branch ||= title_to_ref(self.title)
  end
  
  # Should check the owner's repo to make sure the branch doesn't exist and halt if so
  def before_create
    if self.owner.repository.branches.include?(self.branch)
      return false
    end
  end

  def after_destroy
    self.owner.repository.delete_branch(self.branch)
  end
  
  def submit_to_next_board
    #horrible hack here to specifiy board order, change later with workflow engine
    #1 meta
    #2 transcription
    #3 translation    
    error_text = "" #default to empty for check in controller
    # find all unsubmitted meta ids, then text ids, then translation ids
    [HGVMetaIdentifier, DDBIdentifier, HGVTransIdentifier].each do |ic|
      identifiers.each do |i|
        if i.modified? && i.class == ic &&  i.status == "editing"
          #submit it
          if submit_identifier(i)
            return error_text, i.id
          else            
            error_text  += "no board for " + ic.to_s + " so this publication identifier was NOT submitted"
            return error_text, nil
          end
        end
      end
      
    end
    
    #if we get to this point, nothing else was submitted therefore we are done with publication
    #can this be reached without a commit actually taking place?
=begin
    if error_text != ""
      flash[:warning] = error_text
      # couldnt submit to non exiting board so send back to user?
      #TODO check this
      self.origin.status = "editing" 
      self.save
    end
=end
    self.origin.change_status("committed")
    self.save
    
    return error_text, nil # controller checks returned value for empty or not
    
  end
  
  
  def submit_identifier(identifier)
    
    @recent_submit_sha = "";
    
    #find correct board    
    
    boards = Board.find(:all)
    boards.each do |board|
      if board.identifier_classes && board.identifier_classes.include?(identifier.class.to_s)
        begin
          submit_comment = Comment.find(:last, :conditions => { :publication_id => identifier.publication.id, :reason => "submit" } )
          if submit_comment && submit_comment.comment
            identifier.set_xml_content(
              identifier.add_change_desc(submit_comment.comment),
              :comment => '')
          else
            identifier.set_xml_content(identifier.add_change_desc(), :comment => '')
          end
        rescue ActiveRecord::RecordNotFound
          identifier.set_xml_content(identifier.add_change_desc(), :comment => '')
        end
        
        boards_copy = copy_to_owner(board)
        boards_copy.status = "voting"
        boards_copy.save!
        
        identifier.status = "submitted"
        self.change_status("submitted")
        
        board.send_status_emails("submitted", self)
       
        # self.title = self.creator.name + "/" + self.title
        # self.branch = title_to_ref(self.title)
        # 
        # self.owner.repository.copy_branch_from_repo( duplicate.branch, self.branch, duplicate.owner.repository )
        #(from_branch, to_branch, from_repo)
        self.save!
        identifier.save!
        
        #make the most recent sha for the identifier available...is this the one we want?
        @recent_submit_sha = identifier.get_recent_commit_sha
        return true
      end
    end
    return false #no board exists for this identifier class
  end
  
  def submit
    submit_to_next_board
  end
  
  def self.new_from_templates(creator)
    new_publication = Publication.new(:owner => creator, :creator => creator)
    
    # fetch a title without creating from template
    new_publication.title = DDBIdentifier.new(:name => DDBIdentifier.next_temporary_identifier).titleize
    
    new_publication.status = "new" #TODO add new flag else where or flesh out new status#"new"
    
    new_publication.save!
    
    # branch from master so we aren't just creating an empty branch
    new_publication.branch_from_master
            
    #create the required meta data and transcriptions
    new_ddb = DDBIdentifier.new_from_template(new_publication)      
    new_hgv_meta = HGVMetaIdentifier.new_from_template(new_publication)
            
    # go ahead and create the third so we can get rid of the create button
    #new_hgv_trans = HGVTransIdentifier.new_from_template(new_publication)    
    
    return new_publication
  end
  
  def modified?
    
    retval = false
    self.identifiers.each do |i|
      retval = retval || i.modified?
    end
    
    retval
  end 
  
  def mutable?
    if self.status != "editing" # && self.status != "new"
      return false
    else
      return true
    end
  end
  

  # TODO: rename actual branch after branch attribute rename
  def after_create
  end
  
  #sets the origin status for publication identifiers that the publication's board controls
  def set_origin_identifier_status(status_in)
      #finalizer is a user so they dont have a board, must go up until we find a board
      
      board = self.find_first_board
      if board
              
        self.identifiers.each do |i|
          if board.identifier_classes && board.identifier_classes.include?(i.class.to_s)
            i.origin.status = status_in
            i.origin.save
          end
        end
        
      end
  end

  def set_local_identifier_status(status_in)   

      board = self.find_first_board
      if board
            
        self.identifiers.each do |i|
          if board.identifier_classes && board.identifier_classes.include?(i.class.to_s)
            i.status = status_in
            i.save
          end
        end
        
      end
  end

  def set_origin_and_local_identifier_status(status_in)
    set_origin_identifier_status(status_in)          
    set_local_identifier_status(status_in)          
  end

#needed to set the finalizer's board identifier status
  def set_board_identifier_status(status_in)
      pub = self.find_first_board_parent
      if pub            
        pub.identifiers.each do |i|
          if pub.owner.identifier_classes && pub.owner.identifier_classes.include?(i.class.to_s)
            i.status = status_in
            i.save
          end
        end
        
      end
  end
  
  def change_status(new_status)
    unless self.status == new_status
      old_branch_leaf = self.branch.split('/').last
      new_branch_components = [old_branch_leaf]
      
      unless new_status == 'editing'
        new_branch_components.unshift(new_status, Time.now.strftime("%Y/%m/%d"))
      end
      
      if self.parent && (self.parent.owner.class == Board)
        new_branch_components.unshift(title_to_ref(self.parent.owner.title))
      end
      
      new_branch_name = new_branch_components.join('/')

      # prevent collisions
      if self.owner.repository.branches.include?(new_branch_name)
        new_branch_name += Time.now.strftime("-%H.%M.%S")
      end
    
      # branch from the original branch
      self.owner.repository.create_branch(new_branch_name,
        self.owner.repository.repo.get_head(self.branch).commit.sha)
      # delete the original branch
      self.owner.repository.delete_branch(self.branch)
      # set to new branch
      self.branch = new_branch_name
      # set status to new status
      self.status = new_status
      self.save!
    end
  end
  
  def archive
    self.change_status("archived")
  end
  
  def tally_votes(user_votes = nil)
    user_votes ||= self.votes
    
    #check that we are still taking votes
    if self.status != "voting"
      return "" #return nothing and do nothing since the voting is now over
    end
    
    #need to tally votes and see if any action will take place
    if self.owner_type != "Board" # || !self.owner #make sure board still exist...add error message?
      return "" #another check to make sure only the board is voting on its copy
    else
      decree_action = self.owner.tally_votes(user_votes)
    end
   
    
    # create an event if anything happened
    if !decree_action.nil? && decree_action != ''
      e = Event.new
      e.owner = self.owner
      e.target = self
      e.category = "marked as \"#{decree_action}\""
      e.save!
    end
  
    if decree_action == "approve"
      
      #set local publication status to approved
      self.change_status("approved")
      
      #on approval, set the identifier(s) to approved (local and origin)
      self.set_origin_and_local_identifier_status("approved")
      
      #send emails
       self.owner.send_status_emails("approved", self)
      # @publication.send_status_emails(decree_action)          
      
      #set up for finalizing
      self.send_to_finalizer
      
      
    elsif decree_action == "reject"
      #@publication.get_category_obj().reject       
     
      self.origin.change_status("editing")
      self.set_origin_and_local_identifier_status("editing")
      
      self.owner.send_status_emails("rejected", self)
      
      #do we want to copy ours back to the user? yes
      #TODO test copy to user
      #WARNING since they decided not to let editors edit we don't need to copy back to user 1-28-2010
      #self.copy_repo_to_parent_repo
      
      self.origin.save!
      
      #what to do with our copy?
     # self.status = "rejected" #reset to unsubmitted       
     # self.save
      
      self.destroy
      #redirect to dashboard
     # redirect_to ( dashboard_url )
     # redirect_to :controller => "user", :action => "dashboard"
      #TODO send status emails
      # @publication.send_status_emails(decree_action)
      
    elsif decree_action == "graffiti"               
      # @publication.send_status_emails(decree_action)
      #do destroy after email since the email may need info in the artice
      #@publication.get_category_obj().graffiti
      
      self.owner.send_status_emails("graffiti", self)
      #todo do we let one board destroy the entire document?
      #will this destroy all board copies....
      self.origin.destroy #need to destroy related? 
      self.destroy
     # redirect_to ( dashboard_url )
      #TODO we need to walk the tree and delete everything everywhere??
      #or
      #self.submit_to_next_board
      
    else
      #unknown action or no action    
    end
    
    return decree_action
  end
  
  def flatten_commits(finalizing_publication, finalizer, board_members)
    finalizing_publication.repository.fetch_objects(self.repository)
    
    # flatten commits by original publication creator
    # - use the submission reason as the main comment
    # - concatenate all non-empty commit messages into a list
    # - write a 'Signed-off-by:' line for each Ed. Board member
    # - rewrite the committer to the finalizer
    # - parent will be the branch point from canon (merge-base)
    # - tree will be from creator's last commit
    # - see http://idp.atlantides.org/trac/idp/wiki/SoSOL/Attribution
    # X insert a change in the XML revisionDesc header
    #   should instead happen at submit so EB sees it?
    
    self.owner.repository.update_master_from_canonical
    canon_branch_point = self.merge_base
    
    # this relies on the parent being a remote, e.g. fetch_objects being used
    # during branch copy
    # board_branch_point = self.merge_base(
    #   [self.parent.repository.name, self.parent.branch].join('/'))
    # this works regardless
    board_branch_point = self.origin.head
    
    creator_commits = self.repository.repo.commits_between(canon_branch_point,
                                                           board_branch_point)
    board_commits = self.repository.repo.commits_between(board_branch_point,
                                                         self.head)
    
    reason_comment = self.submission_reason
    
    
    board_controlled_paths = self.controlled_paths
    Rails.logger.info("Controlled Paths: #{board_controlled_paths.inspect}")

    controlled_commits = creator_commits.select do |creator_commit|
      Rails.logger.info("Checking Creator Commit id: #{creator_commit.id}")
      controlled_commit_diffs = Grit::Commit.diff(self.repository.repo, creator_commit.parents.first.id, creator_commit.id, board_controlled_paths.clone)
      controlled_commit_diffs.length > 0
    end
    
    Rails.logger.info("Controlled Commits: #{controlled_commits.inspect}")
    
    creator_commit_messages = [reason_comment.nil? ? '' : reason_comment.comment, '']
    controlled_commits.each do |controlled_commit|
      message = controlled_commit.message.strip
      unless message.empty?
        creator_commit_messages << " - #{message}"
      end
    end
    
    controlled_blobs = board_controlled_paths.collect do |controlled_path|
      self.owner.repository.get_blob_from_branch(controlled_path, self.branch)
    end
    
    controlled_paths_blobs = 
      Hash[*((board_controlled_paths.zip(controlled_blobs)).flatten)]
    
    Rails.logger.info("Controlled Blobs: #{controlled_blobs.inspect}")
    Rails.logger.info("Controlled Paths => Blobs: #{controlled_paths_blobs.inspect}")
    
    signed_off_messages = []
    board_members.each do |board_member|
      signed_off_messages << "Signed-off-by: #{board_member.author_string}"
    end
    
    commit_message =
      (creator_commit_messages + [''] + signed_off_messages).join("\n").chomp
    
    # parent commit should ALWAYS be canonical master head
    # FIXME: handle racing during finalization
    parent_commit = Repository.new.repo.get_head('master').commit.sha
    # parent_commit = canon_branch_point
    
    # roll a tree SHA1 by reading the canonical master tree,
    # adding controlled path blobs, then writing the modified tree
    # (happens on the finalizer's repo)
    finalizer.repository.update_master_from_canonical
    index = finalizer.repository.repo.index
    index.read_tree('master')
    controlled_paths_blobs.each_pair do |path, blob|
      index.add(path, blob.data)
    end
    
    tree_sha1 = index.write_tree(index.tree, index.current_tree)
    Rails.logger.info("Wrote tree as SHA1: #{tree_sha1}")
    # tree_sha1 = self.repository.repo.commit(board_branch_point).tree.id
    
    # most of this is dup'd from Grit::Index#commit
    # with modifications to allow for correct timestamping
    # and author/committer split
    contents = []
    contents << ['tree', tree_sha1].join(' ')
    contents << ['parent', parent_commit].join(' ')
    
    contents << ['author', self.creator.git_author_string].join(' ')
    contents << ['committer', finalizer.git_author_string].join(' ')
    contents << ''
    contents << commit_message
    
    flattened_commit_sha1 = 
      finalizing_publication.repository.repo.git.put_raw_object(
        contents.join("\n"), 'commit')
    
    finalizing_publication.repository.create_branch(
      finalizing_publication.branch, flattened_commit_sha1)
    
    # rewrite commits by EB
    # - write a 'Signed-off-by:' line for each Ed. Board member
    # - rewrite the committer to the finalizer
    # - change parent lineage to flattened commits
  end
  
  #finalizer is a user
  def send_to_finalizer(finalizer = nil)
    board_members = self.owner.users   
    if !finalizer
      #get someone from the board    
#      board_members = self.owner.users    
      # just select a random board member to be the finalizer
      finalizer = board_members[rand(board_members.length)]  
    end
      
    # finalizing_publication = copy_to_owner(finalizer)
    finalizing_publication = clone_to_owner(finalizer)
    self.flatten_commits(finalizing_publication, finalizer, board_members)
    
    #should we clear the modified flag so we can tell if the finalizer has done anything
    # that way we will know in the future if we can change finalizersedidd
    finalizing_publication.change_status('finalizing')
    finalizing_publication.save!
  end  
  
  def remove_finalizer
    # need to find out if there is a finalizer, and take the publication from them
    # finalizer will point back to this board's publication
    current_finalizer_publication = find_finalizer_publication

    # TODO cascading comment deletes?
    if current_finalizer_publication
      current_finalizer_publication.destroy
    end
  
  end
  
  
  def find_finalizer_user
    if find_finalizer_publication
      return find_finalizer_publication.owner    
    end
    return nil
  end
  
  def find_finalizer_publication
  #returns the finalizer user or nil if finalizer does not exist
    Publication.find_by_parent_id( self.id, :conditions => { :status => "finalizing" })
  end
  
  def head
    self.owner.repository.repo.get_head(self.branch).commit.sha
  end
  
  def merge_base(branch = 'master')
    self.owner.repository.repo.git.merge_base({},branch,self.head).chomp
  end
  
  def commit_to_canon
  
    #commit_sha is just used to return git sha reference point for comment
    commit_sha = nil
  
  
    canon = Repository.new
    publication_sha = self.head
    canonical_sha = canon.repo.get_head('master').commit.sha
    
    # FIXME: This walks the whole rev list, should maybe use git merge-base
    # to find the branch point? Though that may do the same internally...
    # commits = canon.repo.commit_deltas_from(self.owner.repository.repo, 'master', self.branch)
    
    # Commits that are in canonical master but not this branch
    # Forcing method_missing here to directly call rev-list is much faster
    commits = self.owner.repository.repo.git.method_missing('rev-list',{}, canonical_sha, "^#{publication_sha}").split("\n")
    
    # canon.repo.git.merge({:no_commit => true, :stat => true},
      # self.owner.repository.repo.get_head(self.branch).commit.sha)
    
    # get the result of merging canon master into this branch
    # merge = Grit::Merge.new(
    #   self.owner.repository.repo.git.merge_tree({},
    #     publication_sha, canonical_sha, publication_sha))
    
    
    if canon_controlled_identifiers.length > 0
      if commits.length == 0
        # nothing new from canon, trivial merge by updating HEAD 
        # e.g. "Fast-forward" merge, HEAD is already contained in the commit
        # canon.fetch_objects(self.owner.repository)
        canon.add_alternates(self.owner.repository)
        commit_sha = canon.repo.update_ref('master', publication_sha)
        
        self.change_status('committed')
        self.save!
      else
        # Both the merged commit and HEAD are independent and must be tied 
        # together by a merge commit that has both of them as its parents.
      
        # TODO: DRY from flatten_commits
        controlled_blobs = self.canon_controlled_paths.collect do |controlled_path|
          self.owner.repository.get_blob_from_branch(controlled_path, self.branch)
        end

        controlled_paths_blobs = 
          Hash[*((self.canon_controlled_paths.zip(controlled_blobs)).flatten)]

        Rails.logger.info("Controlled Blobs: #{controlled_blobs.inspect}")
        Rails.logger.info("Controlled Paths => Blobs: #{controlled_paths_blobs.inspect}")
      
        # roll a tree SHA1 by reading the canonical master tree,
        # adding controlled path blobs, then writing the modified tree
        # (happens on the finalizer's repo)
        self.owner.repository.update_master_from_canonical
        index = self.owner.repository.repo.index
        index.read_tree('master')
        controlled_paths_blobs.each_pair do |path, blob|
          index.add(path, blob.data)
        end

        tree_sha1 = index.write_tree(index.tree, index.current_tree)
        Rails.logger.info("Wrote tree as SHA1: #{tree_sha1}")

        commit_message = "Finalization merge of branch '#{self.branch}' into canonical master"
      
        contents = []
        contents << ['tree', tree_sha1].join(' ')
        contents << ['parent', canonical_sha].join(' ')
        contents << ['parent', publication_sha].join(' ')

        contents << ['author', self.owner.git_author_string].join(' ')
        contents << ['committer', self.owner.git_author_string].join(' ')
        contents << ''
        contents << commit_message
      
        finalized_commit_sha1 = 
          self.owner.repository.repo.git.put_raw_object(
            contents.join("\n"), 'commit')
      
        Rails.logger.info("Finalized commit contents:\n#{contents.join("\n")}")
        Rails.logger.info("Wrote finalized commit merge as SHA1: #{finalized_commit_sha1}")
      
        # Update our own head first
        self.owner.repository.repo.update_ref(self.branch, finalized_commit_sha1)
      
        # canon.fetch_objects(self.owner.repository)
        canon.add_alternates(self.owner.repository)
        commit_sha = canon.repo.update_ref('master', finalized_commit_sha1)
        
        self.change_status('committed')
        self.save!
      end
      
      # finalized, try to repack
      begin
        canon.repo.git.repack({})
      rescue Grit::Git::GitTimeout
        Rails.logger.warn("Canonical repository not repacked after finalization!")
      end
    else
      # nothing under canon control, just say it's committed
      self.change_status('committed')
      self.save!
      
    end
    return commit_sha
  end
  
  
  def branch_from_master
    owner.repository.create_branch(branch)
  end
  
  def controlled_identifiers
    return self.identifiers.select do |i|
      if self.owner.class == Board
        self.owner.identifier_classes.include?(i.class.to_s)
      elsif self.status == 'finalizing'
        self.parent.owner.identifier_classes.include?(i.class.to_s)
      else
        false
      end
    end
  end
  
  def controlled_paths
    self.controlled_identifiers.collect do |i|
      i.to_path
    end
  end
  
  def canon_controlled_identifiers
    # TODO: implement a class-level var e.g. CANON_CONTROL for this
    self.controlled_identifiers.select{|i| !([HGVMetaIdentifier, HGVBiblioIdentifier].include?(i.class))}
  end
  
  def canon_controlled_paths
    self.canon_controlled_identifiers.collect do |i|
      i.to_path
    end
  end
  
  def diff_from_canon
    canon = Repository.new
    canonical_sha = canon.repo.get_head('master').commit.sha
    diff = self.owner.repository.repo.git.diff(
      {:unified => 5000}, canonical_sha, self.head,
      '--', *(self.controlled_paths))
    return diff || ""
  end
  
  def submission_reason
    reason = Comment.find_by_publication_id(self.origin.id,
      :conditions => "reason = 'submit'")
  end
  
  def origin
    # walk the parent list until we encounter one with no parent
    origin_publication = self
    while (origin_publication.parent != nil) do
      origin_publication = origin_publication.parent
    end
    return origin_publication
  end
  
  #finds the closest parent publication whose owner is a board and returns that board
  def find_first_board
    board_publication = self
    while (board_publication.owner_type != "Board" && board_publication != nil) do
      board_publication = board_publication.parent
    end
    if board_publication
      return board_publication.owner
    end
    return nil
  end
  
  #finds the closest parent publication whose owner is a board and returns that publication
  def find_first_board_parent
    board_publication = self
    while (board_publication.owner_type != "Board" && board_publication != nil) do
      board_publication = board_publication.parent
    end
    return board_publication      
  end

  #total votes for the publication children in voting status
  def children_votes
    vote_total = 0
    vote_ddb = 0
    vote_meta = 0
    vote_trans = 0
    self.children.each do|x|
      if x.status == 'voting'
        x.identifiers.each do |y|
          case y
            when DDBIdentifier
              vote_ddb += y.votes.length
              vote_total += vote_ddb
            when HGVMetaIdentifier
              vote_meta += y.votes.length
              vote_total += vote_meta
            when HGVTransIdentifier
              vote_trans += y.votes.length
              vote_total += vote_trans
          end #case
        end # identifiers do
      end #if
    end #children do
    return vote_total, vote_ddb, vote_meta, vote_trans
  end

  def clone_to_owner(new_owner)
    duplicate = self.clone
    duplicate.owner = new_owner
    duplicate.creator = self.creator
    duplicate.title = self.owner.name + "/" + self.title
    duplicate.branch = title_to_ref(duplicate.title)
    duplicate.parent = self
    duplicate.save!
    
    # copy identifiers over to new pub
    identifiers.each do |identifier|
      duplicate_identifier = identifier.clone
      duplicate.identifiers << duplicate_identifier
    end
    
    return duplicate
  end
  
  def repository
    return self.owner.repository
  end
  
  #copies this publication's branch to the new_owner's branch
  #returns duplicate publication with new_owner
  def copy_to_owner(new_owner)
    duplicate = self.clone_to_owner(new_owner)
    
    duplicate.owner.repository.copy_branch_from_repo(
      self.branch, duplicate.branch, self.owner.repository
    )
    
    return duplicate
  end
    
  #copy a child publication repo back to the parent repo
  def copy_repo_to_parent_repo
     #all we need to do is copy the repo back the parents repo
     self.origin.repository.copy_branch_from_repo(self.branch, self.origin.branch, self.repository)
  end
  
  # TODO: destroy branch on publication destroy
  
  # entry point identifier to use when we're just coming in from a publication
  def entry_identifier
    identifiers.first
  end
  
  def get_all_comments(title)
    all_built_comments = []
    xml_only_built_comments = []
    # select all comments associated with a publication title - will include from all users
    @arcomments = Comment.find_by_sql("SELECT a.comment, a.user_id, a.identifier_id, a.reason, a.created_at 
                                         FROM comments a, publications b 
                                        WHERE b.title = '#{title}'
                                          AND a.publication_id = b.id
                                     ORDER BY a.created_at DESC")
    # add comments hash to array
    @arcomments.each do |c|
      built_comment = Comment::CombineComment.new
      
      built_comment.xmltype = "model"
      
      if c.user && c.user.name
        built_comment.who = c.user.human_name
      else
        built_comment.who = "user not filled in"
      end
      # convert date to local for consistency so work in sort below
      built_comment.when = c.created_at.getlocal
      
      if c.reason
        built_comment.why = c.reason
      else
        built_comment.why = "reason not filled in"
      end
      #add identifier name if available
      if c.identifier
        built_comment.why = built_comment.why + " " + c.identifier.class::FRIENDLY_NAME
      end
      
      if c.comment
        built_comment.comment = c.comment
      else
        built_comment.comment = "comment not filled in"
      end

      all_built_comments << built_comment
    end

    # add comments hash from each of the publication's identifiers XML file to array
    identifiers.each do |i|
      where_from = i.class::FRIENDLY_NAME
      ident_title = i.title
      
      ident_xml = i.xml_content
      if ident_xml
        ident_xml_xpath = REXML::Document.new(ident_xml)
        comment_path = '/TEI/teiHeader/revisionDesc'
        comment_here = REXML::XPath.first(ident_xml_xpath, comment_path)
        
        comment_here.each_element('//change') do |change|
          built_comment = Comment::CombineComment.new
          
          built_comment.xmltype = where_from
          
          if change.attributes["who"]
            built_comment.who = change.attributes["who"]
          else
            built_comment.who = "no who attribute"
          end
          
          # parse will convert date to local for consistency so work in sort below
          if change.attributes["when"]
            built_comment.when = Time.parse(change.attributes["when"])
          else
            built_comment.when = Time.parse("1988-8-8")
          end
          
          built_comment.why = "From "  + ident_title + " " + where_from + " XML"
          
          built_comment.comment = change.text
          
          all_built_comments << built_comment
          xml_only_built_comments << built_comment
        end #comment_here
      end # if ident_xml
    end #identifiers each
    # sort in descending date order for display
    return all_built_comments.sort_by(&:when).reverse, xml_only_built_comments.sort_by(&:when).reverse
  end
  
  protected
    #Returns title string in form acceptable to  ".git/refs/"
    def title_to_ref(str)
      str.tr(' ','_')
    end

    #Returns identifier string in form acceptable to  ".git/refs/"
    def identifier_to_ref(str)
      str.tr(':;','_')
    end
end
