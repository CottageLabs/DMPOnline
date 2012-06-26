class RepositoryQueue < ActiveRecord::Base
  belongs_to :repository
  belongs_to :repository_queue_status
  
  validates :repository_id, :presence => true
  validates :plan_id, :presence => true
  validates :phase_edition_instance_id, :presence => true
  validates :user_id, :presence => true
  validates :submitted_date, :presence => true
  validates :repository_queue_status_id, :presence => true
  validates :status_date, :presence => true
      
  attr_accessible :repository_id, :plan_id, :phase_edition_instance_id, :user_id, :submitted_date, :repository_queue_status_id, :status_date, :log
  
end
