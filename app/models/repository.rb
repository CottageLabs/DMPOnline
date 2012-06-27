class Repository < ActiveRecord::Base

  cattr_accessor :config
    
  belongs_to :organisation
  has_many :repository_queues
  
  attr_accessible :name, :organisation_id, :collection_iri, :username, :password, :administrator_name, :administrator_email

  validates :name, :uniqueness => true, :presence => true
  validates :organisation_id, :uniqueness => true
  validates :organisation, :presence => true
  validates :administrator_email, :email => true
  validates :collection_iri, :url => true

  def show_log(phase_edition_instance)
    "this is the log for project: #{phase_edition_instance.template_instance.plan.project}"
  end
  


end
