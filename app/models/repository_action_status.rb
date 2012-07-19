class RepositoryActionStatus < ActiveRecord::Base

   has_many :repository_action_queues

   attr_accessible :name, :description

   validates :name, :uniqueness => true, :presence => true

   def self.Initialising_id
     return self.find_by_name('Initialising').id
   end

   def self.Pending_id
     return self.find_by_name('Pending').id
   end

   def self.Processing_id
     return self.find_by_name('Processing').id
   end

   def self.Failed_Requeue_id
     return self.find_by_name('Failed - Requeue').id
   end

   def self.Failed_Terminated_id
     return self.find_by_name('Failed - Terminated').id
   end

   def self.Success_id
     return self.find_by_name('Success').id
   end
   
   def self.Removed_id
     return self.find_by_name('Removed').id
   end
end
