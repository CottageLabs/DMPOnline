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

   def self.Failed_id
     return self.find_by_name('Failed').id
   end

   def self.Success_id
     return self.find_by_name('Success').id
   end
   
end
