class RepositoryActionType < ActiveRecord::Base
  
   has_many :repository_action_queues

   attr_accessible :name, :description

   validates :name, :uniqueness => true, :presence => true

   def self.Create_Metadata_id
     return self.find_by_name('Create Metadata').id
   end

   def self.Create_Metadata_Media_id
     return self.find_by_name('Create Metadata and Media').id
   end
   
   def self.Replace_Media_id
     return self.find_by_name('Replace Media').id
   end

   def self.Add_Media_id
     return self.find_by_name('Add Media').id
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
