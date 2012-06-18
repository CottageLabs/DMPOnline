class Repository < ActiveRecord::Base
  belongs_to :organisation
  attr_accessible :name, :organisation, :collection_iri, :username, :password, :administrator_name, :administrator_email
  
end
