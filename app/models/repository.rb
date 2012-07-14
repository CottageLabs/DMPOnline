require 'sword2ruby'

class Repository < ActiveRecord::Base

  cattr_accessor :config
    
  belongs_to :organisation
  has_many :repository_action_queues
  has_many :plans
  
  attr_accessible :name, :organisation_id, :sword_collection_uri, :username, :password, :administrator_name, :administrator_email
  attr_accessible :create_metadata_with_new_plan
  attr_accessible :filetype_rdf, :filetype_pdf, :filetype_html, :filetype_csv, :filetype_txt, :filetype_xml, :filetype_xlsx, :filetype_docx, :filetype_rtf

  validates :name, :uniqueness => true, :presence => true
  validates :organisation_id, :uniqueness => true
  validates :organisation, :presence => true
  validates :administrator_email, :email => true
  validates :sword_collection_uri, :url => true

  
  def get_connection(on_behalf_of = nil)
    user = Sword2Ruby::User.new(self.username, self.password, on_behalf_of);
    connection = Sword2Ruby::Connection.new(user);    
  end

end
