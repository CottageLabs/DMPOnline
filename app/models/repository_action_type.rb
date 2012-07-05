class RepositoryActionType < ActiveRecord::Base
  
   has_many :repository_action_queues

   attr_accessible :name, :description

   validates :name, :uniqueness => true, :presence => true

   def self.Create_id
     return self.find_by_name('Create').id
   end

   def self.Export_id
     return self.find_by_name('Export').id
   end

   def self.Finalise_id
     return self.find_by_name('Finalise').id
   end

   def self.Duplicate_id
     return self.find_by_name('Duplicate').id
   end

   def self.Delete_id
     return self.find_by_name('Delete').id
   end

   
end
