class Repository < ActiveRecord::Base
  belongs_to :organisation
  attr_accessible :name, :organisation_id, :collection_iri, :username, :password, :administrator_name, :administrator_email

  validates :name, :uniqueness => true, :presence => true
  validates :organisation_id, :uniqueness => true
  validates :organisation, :presence => true
  validates :administrator_email, :email => true
  
  
#  validates :password, :confirmation => true

  
#  
  
  
end
