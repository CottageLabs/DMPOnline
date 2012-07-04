require 'bagit'
require 'zip/zip'

class RepositoryActionQueue < ActiveRecord::Base
  
  belongs_to :repository
  belongs_to :repository_action_status
  belongs_to :repository_action_type
  
  validates :repository_id, :presence => true #If you delete a repository, you should delete its queue first
  validates :plan_id, :presence => false #The plan could be deleted before the queue, hence could be null
  validates :phase_edition_instance_id, :presence => false  #The PEI could be deleted before the queue, hence could be null
  validates :user_id, :presence => false  #The user could be deleted before the queue, hence could be null

  validates :repository_action_type_id, :presence => true    
  validates :repository_action_status_id, :presence => true

  attr_accessible :repository_id, :plan_id, :phase_edition_instance_id, :user_id, 
    :repository_action_type_id, :repository_action_status_id, :repository_action_uri, :repository_action_receipt, :repository_action_log
  
  
  def self.enqueue(repository_action_type_id, repository, plan, phase_edition_instance, user, files=[])   
    #Create a queue record
    queue_entry = self.create!(
      :repository_id=>repository.id, 
      :plan_id => plan.id,
      :phase_edition_instance_id => phase_edition_instance.id,
      :user_id => user.id,
      :repository_action_type_id => repository_action_type_id,
      :repository_action_status_id => RepositoryActionStatus.Initialising_id,
      :repository_action_uri => "FIX ME",
      :repository_action_log => "Initialised on #{DateTime.now}."
)
      
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
    queue_entry.repository_action_status_id = RepositoryActionStatus.Pending_id
    queue_entry.save!
    
    return queue_entry
  end
  
  
  def self.process
    logger.info "Processing the repository queue."
    entries = RepositoryQueue.all(
      :conditions=> {:repository_action_status_id=>RepositoryActionStatus.Pending_id},
      :order=>"created_at asc")
    logger.info "There are #{entries.count} item(s) in the queue to process"
    entries.each do |entry|
      logger.info "Processing #{entry.id}"
      entry.repository_action_status_id = RepositoryActionStatus.Processing_id;
      entry.save!
      
      
      
    end
    
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
