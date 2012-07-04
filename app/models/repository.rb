require 'sword2ruby'

class Repository < ActiveRecord::Base

  cattr_accessor :config
    
  belongs_to :organisation
  has_many :repository_action_queues
  
  attr_accessible :name, :organisation_id, :sword_col_uri, :username, :password, :administrator_name, :administrator_email

  validates :name, :uniqueness => true, :presence => true
  validates :organisation_id, :uniqueness => true
  validates :organisation, :presence => true
  validates :administrator_email, :email => true
  validates :sword_col_uri, :url => true

  def show_log(phase_edition_instance = nil)
    # If a phase_edition_instance is specified, return top 10 relevant queue entries, order by date (descending),
    # for display on the phase_edition_instance page
    if (phase_edition_instance)
      return {:title => phase_edition_instance.template_instance.plan.project,
        :entries => RepositoryActionQueue.all(
          :conditions=> {:phase_edition_instance_id=>phase_edition_instance.id, :repository_id => self.id},
          :limit => 10, 
          :order=>"created_at desc", 
          :select=>"id, created_at, repository_action_type_id, repository_action_status_id, repository_action_log", 
          :include=>[:repository_action_status, :repository_action_type])
        }
      else
        #Otherwise, return all queue entries
        return {:title => name,
          :entries => RepositoryActionQueue.all(
            :conditions => {:repository_id => self.id},
            :order=>"created_at desc", 
            :include=>[:repository_action_status, :repository_action_type])
          }
        
    end
  end
  
  
  def get_connection(on_behalf_of = nil)
    user = Sword2Ruby::User.new(self.username, self.password, on_behalf_of);
    connection = Sword2Ruby::Connection.new(user);    
  end

end
