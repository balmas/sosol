#Represents a system user.
class User < ActiveRecord::Base
  
  NAMESPACE_IDENTIFIER = "perseus.org"
  validates_uniqueness_of :name, :case_sensitive => false
  
  has_many :user_identifiers, :dependent => :destroy

  #worksA has_and_belongs_to_many :community_memberships, :class_name => "Community", :foreign_key => "user_id",    :join_table => "communities_members"
  #worksA has_and_belongs_to_many :community_admins,  :class_name => "Community", :foreign_key => "user_id", :join_table => "communities_admins"
 
  has_and_belongs_to_many :community_memberships, :class_name => "Community", :association_foreign_key => "community_id", :foreign_key => "user_id",    :join_table => "communities_members"
  has_and_belongs_to_many :community_admins,  :class_name => "Community", :association_foreign_key => "community_id", :foreign_key => "user_id", :join_table => "communities_admins"

  
  has_and_belongs_to_many :boards
  has_many :finalizing_boards, :class_name => 'Board', :foreign_key => 'finalizer_user_id'
  
  has_and_belongs_to_many :emailers
  
  has_many :publications, :as => :owner, :dependent => :destroy
  has_many :events, :as => :owner, :dependent => :destroy
  
  has_many :comments
  
  has_repository
  
  def after_create
    repository.create

    if ENV['RAILS_ENV'] != 'test'
      if ENV['RAILS_ENV'] == 'development'
        self.admin = true
        self.save!
      
        [].each do |pn_id|
          p = Publication.new
          p.owner = self
          p.creator = self
          p.populate_identifiers_from_identifiers(pn_id)
          p.save!
          p.branch_from_master
              
          e = Event.new
          e.category = "started editing"
          e.target = p
          e.owner = self
          e.save!
        end # each
      end # == development
    end # != test
  end # after_create
  
  def human_name
    # get user name
    if self.full_name && self.full_name.strip != ""
      return self.full_name.strip
    else
      return who_name = self.name
    end
  end
  
  def grit_actor
    Grit::Actor.new(self.full_name, self.email)
  end
  
  def author_string
    "#{self.full_name} <#{self.email}>"
  end
  
  def git_author_string
    local_time = Time.now
    "#{self.author_string} #{local_time.to_i} #{local_time.strftime('%z')}"
  end
  
  def before_destroy
    repository.destroy
  end
  
  #Sends an email to all users on the system that have an email address.
  #*Args*
  #- +subject_line+ the email's subject
  #- +email_content+ the email's body
  def self.compose_email(subject_line, email_content)
    #get email addresses from all users that have them
    #users = User.find(:all, :select => "email", :conditions => ["email != ?", ""])
    users = User.find_by_sql("SELECT email From users WHERE email is not null")
    
    users.each do |toaddress|
      if toaddress.email.strip != ""
        EmailerMailer.deliver_send_email_out(toaddress.email, subject_line, email_content)			
      end
    end
    
    #can use below if want to send to all addresses in 1 email
    #format 'to' addresses for actionmailer
    #addresses = users.map{|c| c.email}.join(", ")
    #EmailerMailer.deliver_send_email_out(addresses, subject_line, email_content)
    
  end
end
