require 'bagit'
require 'zip/zip'
require 'sword2ruby'

class RepositoryActionQueue < ActiveRecord::Base
  
  belongs_to :repository
  belongs_to :repository_action_status
  belongs_to :repository_action_type
  belongs_to :user
  belongs_to :plan
  belongs_to :phase_edition_instance
    
  validates :repository_id, :presence => true #If you delete a repository, you should delete its queue first
  validates :plan_id, :presence => false #The plan could be deleted before the queue, hence could be null
  validates :phase_edition_instance_id, :presence => false  #The PEI could be deleted before the queue, hence could be null
  validates :user_id, :presence => false  #The user could be deleted before the queue, hence could be null

  validates :repository_action_type_id, :presence => true    
  validates :repository_action_status_id, :presence => true

  attr_accessible :repository_id, :plan_id, :phase_edition_instance_id, :user_id, 
    :repository_action_type_id, :repository_action_status_id, :repository_action_uri, :repository_action_receipt, :repository_action_log
  
  
  #Cannot store URI in advance of action (except for delete), as then its not possible to create + update without queue running in between.
  def self.enqueue(repository_action_type_id, repository, plan, phase_edition_instance, user, files=[])

    #When repository_action_uri is null, this means, work it out on the fly
    #When it is set (e.g. for deletes), use it. It is necessary to cache the URI for deletes in case the original
    #record has been removed from the system
    repository_action_uri = (repository_action_type_id == RepositoryActionType.Delete_id) ? "DELETE on EDIT-URI" : nil;
        
  #case repository_action_type_id
  #  when RepositoryActionType.Create_id #POST Atom to COLLECTION URI
  #    repository_action_uri = repository.sword_col_uri
  #  when RepositoryActionType.Export_id #PUT Package to EM-URI
  #    repository_action_uri = "PUT PACKAGE TO EM-URI"
  #  when RepositoryActionType.Finalise_id #PUT Package to EM-URI + POST to EDIT-URI
  #    repository_action_uri = "PUT PACKAGE TO EM-URI THEN POST TO EDIT-URI"
  #when RepositoryActionType.Delete_id #DELETE on EDIT URI
  #  repository_action_uri = "DELETE on EDIT-URI"


    #Create a queue record
    queue_entry = self.create!(
      :repository_id=>repository.id, 
      :plan_id => plan.id,
      :phase_edition_instance_id => phase_edition_instance.id,
      :user_id => user.id,
      :repository_action_type_id => repository_action_type_id,
      :repository_action_status_id => RepositoryActionStatus.Initialising_id,
      :repository_action_uri => repository_action_uri,
      :repository_action_log => "Initialised on #{Time.now}."
    )

    #If there are files, put them in a bag and zip them up
    if (files.length > 0)
      
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
      
    end
      
    
    #Update queue entry to pending
    queue_entry.repository_action_status_id = RepositoryActionStatus.Pending_id
    queue_entry.save!
    
    return queue_entry
  end
  
  
  def self.process
    logger.info "Processing the repository queue."
    queue_items = self.all(
      :conditions=> {:repository_action_status_id=>RepositoryActionStatus.Pending_id},
      :order=>"created_at asc")
    logger.info "There are #{queue_items.count} item(s) in the queue to process"
    
    deposit_receipt = nil
    
    queue_items.each do |item|
      logger.info "Processing #{item.id}"

      #record item as being processed
      item.repository_action_status_id = RepositoryActionStatus.Processing_id;
      item.save!
      
      logger.info "Getting connection to repository with on_behalf_of username"
      connection = item.repository.get_connection(item.user.repository_username)

      #Now process the queue acording to the type
      case item.repository_action_type_id
      
        #Creating a blank record (no files)
        when RepositoryActionType.Create_id
          
          # If the queue's repository_action_uri is set, use it, otherwise use the repository's sword_col_uri
          item.repository_action_uri ||= item.repository.sword_col_uri
          
          logger.info "Creating entry in #{item.repository_action_uri}"
          
          
          collection = ::Atom::Collection.new(item.repository_action_uri, connection)
          
          entry = Atom::Entry.new()
          entry.title = item.plan.project
          entry.summary = "DMP with template: #{item.phase_edition_instance.template_instance.template.name}"
          entry.updated = Time.now
          
          slug = "#{item.plan.project.parameterize}_#{Time.now.strftime("%FT%H-%M-%S")}"

          deposit_receipt = collection.post!(:entry=>entry, :slug=>slug, :in_progress=>true)
          
          item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s
          item.repository_action_log += "\nCREATE to #{item.repository_action_uri} on #{Time.now}."
          item.phase_edition_instance.sword_edit_uri = deposit_receipt.entry.sword_edit_uri
          item.phase_edition_instance.sword_edit_media_uri = deposit_receipt.entry.edit_media_links().first.href
          
          item.phase_edition_instance.save!

          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += "\nSuccess - at #{Time.now}."
          
        #Performing an export (with files) / finalising
        when RepositoryActionType.Export_id #, RepositoryActionType.Finalise_id
          # If the queue's repository_action_uri is set, use it, otherwise use the PEI repository's Edit Media URI (via PUT)
          item.repository_action_uri ||= item.phase_edition_instance.sword_edit_media_uri
          
          entry = Atom::Entry.new()
          entry.links.new(:href => item.repository_action_uri, :rel=>"edit-media") #this is a hack to get around a bug in sword2ruby
          
          #Meta data is coming from the RDF file wihin the zip-bagit file
          deposit_receipt = entry.put_media!(
            :filepath => REPOSITORY_PATH.join('queue',"#{item.id}.zip").to_s,
            :content_type => "application/zip",
            :connection => connection,
            :metadata_relevant => true
          )
          
          if deposit_receipt.has_entry
            item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s            
          end
          item.repository_action_log += "\nEXPORT to #{item.repository_action_uri} on #{Time.now}."
          
          #If we are finalising the item, need a further Post
          #if (item.repository_action_type_id == RepositoryActionType.Finalise_id)
          #  entry = Atom::Entry.new()
          #  entry.post!(:sword_edit_uri => item.phase_edition_instance.sword_edit_uri, :in_progress => false, :connection => connection)
          #  item.repository_action_log += "\nFINALISE to #{item.phase_edition_instance.sword_edit_uri} on #{Time.now}."
          #end
          
          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += "\nSuccess - at #{Time.now}."            
        
        when RepositoryActionType.Finalise_id
          # If the queue's repository_action_uri is set, use it, otherwise use the PEI repository's Edit Media URI (via PUT)
          item.repository_action_uri ||= item.phase_edition_instance.sword_edit_uri
          
          entry = Atom::Entry.new()

          deposit_receipt = entry.post!(:sword_edit_uri => item.repository_action_uri, :in_progress => false, :connection => connection)
          item.repository_action_log += "\nFINALISE to #{item.repository_action_uri} on #{Time.now}."
          if deposit_receipt.has_entry
            item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s            
          end
          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += "\nSuccess - at #{Time.now}."            


        when RepositoryActionType.Duplicate_id
          
          # If the queue's repository_action_uri is set, use it, otherwise use the repository's sword_col_uri
          item.repository_action_uri ||= item.repository.sword_col_uri
          
          logger.info "Creating entry in #{item.repository_action_uri}"
          
          
          collection = ::Atom::Collection.new(item.repository_action_uri, connection)
          
          entry = Atom::Entry.new()
          entry.title = item.plan.project
          entry.summary = "DMP with template: #{item.phase_edition_instance.template_instance.template.name}."
          entry.add_dublin_core_extension!("relation", "Duplicate of ???")
          entry.updated = Time.now
          
          slug = "#{item.plan.project.parameterize}_#{Time.now.strftime("%FT%H-%M-%S")}"

          deposit_receipt = collection.post!(:entry=>entry, :slug=>slug, :in_progress=>true)
          
          item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s
          item.repository_action_log += "\nDUPLICATE to #{item.repository_action_uri} on #{Time.now}."
          item.phase_edition_instance.sword_edit_uri = deposit_receipt.entry.sword_edit_uri
          item.phase_edition_instance.sword_edit_media_uri = deposit_receipt.entry.edit_media_links().first.href
          
          item.phase_edition_instance.save!

          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += "\nSuccess - at #{Time.now}."


        else
          item.repository_action_status_id = RepositoryActionStatus.Failed_id;
          item.repository_action_log += "\nFailed - no handler for requested action type #{item.repository_action_type} at #{Time.now}."
          

      end
      
      item.save!      
    end
    
  end
  
  
  #Helper function
  private
  def self.add_directory_to_zipfile(directory, base_directory, zipfile)
    puts "TEST self.add_directory_to_zipfile(#{directory}, #{base_directory})"
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
