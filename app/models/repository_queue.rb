require 'bagit'
require 'zip/zip'

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
  
  
  def self.enqueue(repository, plan, phase_edition_instance, user, files=[])   
    #Create a queue record
    queue_entry = self.create!(
      :repository_id=>repository.id, 
      :plan_id => plan.id,
      :phase_edition_instance_id => phase_edition_instance.id,
      :repository_queue_status_id => RepositoryQueueStatus.Initialising_id,
      :user_id => user.id,
      :submitted_date => DateTime.now,
      :status_date => DateTime.now)
      
    #Create the temporary file area
    bagit_path = REPOSITORY_PATH.join('queue', queue_entry.id.to_s)
    FileUtils.mkdir_p(bagit_path)
    
    # make a new bag at base_path
    bag = BagIt::Bag.new(bagit_path)
    
    #Export the files to the bag
    files.each do |file|
      bag.add_file(file[:filename]) do |io|
        io.binmode if (file[:binary])
        io << file[:data]
      end
    end

    # generate the manifest and tagmanifest files
    bag.manifest!      
    
    #Now zip it all up
    Zip::ZipFile.open(REPOSITORY_PATH.join('queue',"#{queue_entry.id}.zip").to_s, Zip::ZipFile::CREATE) do |zipfile|
      self.add_directory_to_zipfile(bagit_path, bagit_path, zipfile)
    end
    
    #Remove the old bagit folder
    FileUtils.rm_rf bagit_path
    
    #Update queue entry to pending
    queue_entry.repository_queue_status_id = RepositoryQueueStatus.Pending_id
    queue_entry.status_date = DateTime.now
    queue_entry.save!
    
    return queue_entry
  end
  
  #Helper function
  private
  def self.add_directory_to_zipfile(directory, base_directory, zipfile)          
    directory.children(true).each do |entry|
      relative_entry = entry.relative_path_from(base_directory)
      if (entry.file?)
        zipfile.add(relative_entry.to_s, entry.to_s)
      elsif (entry.directory?)
        zipfile.mkdir(relative_entry.to_s)
        self.add_directory_to_zipfile(entry, base_directory, zipfile) #recursion!
      end
    end #each    
  end #def
  
  
end
