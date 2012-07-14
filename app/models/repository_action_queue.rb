require 'bagit'
require 'zip/zip'
require 'sword2ruby'

class RepositoryActionQueue < ActiveRecord::Base
  
  extend ActionView::Helpers::NumberHelper #using number_to_human_size function
  
  belongs_to :repository
  belongs_to :repository_action_status
  belongs_to :repository_action_type
  belongs_to :user
  belongs_to :plan
  belongs_to :phase_edition_instance
    
  validates :repository_id, :presence => true #If you delete a repository, you should delete its queue first
  validates :repository_action_type_id, :presence => true    
  validates :repository_action_status_id, :presence => true
  
#  validates :plan_id, :presence => false #The plan could be deleted before the queue, hence could be null
#  validates :phase_edition_instance_id, :presence => false  #The PEI could be deleted before the queue, hence could be null
#  validates :user_id, :presence => false  #The user could be deleted before the queue, hence could be null


  attr_accessible :repository_id, :plan_id, :phase_edition_instance_id, :user_id, 
    :repository_action_type_id, :repository_action_status_id, :repository_action_uri, :repository_action_receipt, :repository_action_log
    

  #Get a list of the latest repository queue actions
  def self.latest(repository, plan = nil, phase_edition_instance = nil, limit = REPOSITORY_LOG_LENGTH)
    conditions = {:repository_id => repository.id}
    conditions[:plan_id] = plan.id if plan
    conditions[:phase_edition_instance_id] = phase_edition_instance.id if phase_edition_instance
    
    all(  :conditions => conditions,
          :limit => limit, 
          :order=>"id desc", 
          :include=>[:repository_action_status, :repository_action_type]) #, :user, :plan
  end
  
  
  #Cannot store URI in advance of action (except for delete), as then its not possible to create + update without queue running in between.
  def self.enqueue(repository_action_type_id, repository, plan, phase_edition_instance, user, files=[])

    #When repository_action_uri is null, this means work it out on the fly (i.e. when the queue is processed, not when the item is queued)
    #When it is set (e.g. for deletes), use it. It is necessary to cache the URI for deletes because the original record will have been removed from the system
    
    case repository_action_type_id
    when RepositoryActionType.Delete_id
      repository_action_uri = plan.repository_entry_edit_uri
      plan_id = nil
      phase_edition_instance_id = nil
    else
      repository_action_uri = nil
      plan_id = plan.id
      phase_edition_instance_id = phase_edition_instance ? phase_edition_instance.id : nil
    end

    #Create a queue record
    queue_entry = self.create!(
      :repository_id=>repository.id, 
      :plan_id => plan_id,
      :phase_edition_instance_id => phase_edition_instance_id,
      :user_id => user.id,
      :repository_action_type_id => repository_action_type_id,
      :repository_action_status_id => RepositoryActionStatus.Initialising_id,
      :repository_action_uri => repository_action_uri,
      :repository_action_log => log_message("Initialised")
    )


    #If there are files, put them in a bag and zip them up
    if (files.length > 0)
      queue_entry.repository_action_log += log_message("Archiving #{files.length} file(s)")
      
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
        queue_entry.repository_action_log += log_message("Bagged file: #{file[:filename]} (#{number_to_human_size(file[:data].length)})")
      end

      # generate the manifest and tagmanifest files
      bag.manifest!      

      #Now zip it all up
      zipfilename = REPOSITORY_PATH.join('queue',"#{queue_entry.id}.zip").to_s
      Zip::ZipFile.open(zipfilename, Zip::ZipFile::CREATE) do |zipfile|
        self.add_directory_to_zipfile(bagit_path, bagit_path, zipfile)
      end
      
      #Remove the old bagit folder
      FileUtils.rm_rf bagit_path
      
      queue_entry.repository_action_log += log_message("Zip archive: #{File.basename(zipfilename)} (#{number_to_human_size(File.size(zipfilename))})")
    else
      queue_entry.repository_action_log += log_message("No files archived")
    end
      
    
    #Update queue entry to pending
    queue_entry.repository_action_status_id = RepositoryActionStatus.Pending_id
    queue_entry.save!
    
    return queue_entry
  end
  
  
  

    
  
  def self.process
    
    #case repository_action_type_id
    #  when RepositoryActionType.Create_id #POST Atom to COLLECTION URI
    #    repository_action_uri = repository.sword_collection_uri
    #  when RepositoryActionType.Export_id #PUT Package to EM-URI
    #    repository_action_uri = "PUT PACKAGE TO EM-URI"
    #  when RepositoryActionType.Finalise_id #PUT Package to EM-URI + POST to EDIT-URI
    #    repository_action_uri = "PUT PACKAGE TO EM-URI THEN POST TO EDIT-URI"
    #when RepositoryActionType.Delete_id #DELETE on EDIT URI
    #  repository_action_uri = "DELETE on EDIT-URI"
    
    
    logger.info "Processing the repository queue."
    queue_items = self.all(
      :conditions=> {:repository_action_status_id=>RepositoryActionStatus.Pending_id},
      :order=>"id asc") #first in, first out
    logger.info "There are #{queue_items.count} item(s) in the queue to process"
      
    queue_items.each do |item|      
      logger.info "Processing #{item.id}"

      deposit_receipt = nil

      #record item as being processed
      item.repository_action_status_id = RepositoryActionStatus.Processing_id;
      item.repository_action_log +=  log_message("Processing")
      item.save!
      

      logger.info "Getting connection to repository with on_behalf_of username"
      connection = item.repository.get_connection(item.user.repository_username)



      #Now process the queue acording to the type
      case item.repository_action_type_id
      
        #Creating a blank record (no files) | Duplicating a record
        when RepositoryActionType.Create_id, RepositoryActionType.Duplicate_id
          
          # If the queue's repository_action_uri is set, use it, otherwise use the repository's Collection URI
          item.repository_action_uri ||= item.repository.sword_collection_uri
          item.repository_action_log +=  log_message( "<a href=\"#{item.repository_action_uri}\">Collection URI</a>") if item.repository_action_uri
          
          collection = ::Atom::Collection.new(item.repository_action_uri, connection)
          
          entry = Atom::Entry.new()
          entry.title = item.plan.project
          summary = "Data management plan.";
          summary += " Lead organisation: #{item.plan.lead_org}." if item.plan.lead_org
          summary += " Start date: #{item.plan.start_date.to_s("%F")}." if item.plan.start_date          
          entry.summary = summary
          entry.add_dublin_core_extension!("relation", item.plan.source_plan.repository_entry_edit_uri) if item.plan.source_plan #Store duplicate relation
          entry.updated = Time.now
          
          slug = "#{item.plan.project.parameterize}_#{Time.now.strftime("%FT%H-%M-%S")}"

          deposit_receipt = collection.post!(:entry=>entry, :slug=>slug, :in_progress=>true)
          
          if (deposit_receipt && deposit_receipt.has_entry)
            item.plan.repository_content_uri = deposit_receipt.entry.content.src if deposit_receipt.entry.content && deposit_receipt.entry.content.src
            item.plan.repository_entry_edit_uri = deposit_receipt.entry.entry_edit_uri if deposit_receipt.entry.entry_edit_uri
            item.plan.repository_edit_media_uri = deposit_receipt.entry.edit_media_links.first.href if deposit_receipt.entry.edit_media_links.length > 0
            item.plan.repository_sword_edit_uri = deposit_receipt.entry.sword_edit_uri if deposit_receipt.entry.sword_edit_uri
            item.plan.repository_sword_statement_uri = deposit_receipt.entry.sword_statement_links.first.href if deposit_receipt.entry.sword_statement_links.length > 0
            
            logger.info ("ABOUT TO SAVE THE PLAN")
            logger.info (item.plan.id)
            logger.info (item.plan)
            
            item.plan.save!

            logger.info ("SAVED THE PLAN")


            
            item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s
            
            item.repository_action_log +=  log_message( "<a href=\"#{item.plan.repository_content_uri}\">Content URI</a>") if item.plan.repository_content_uri
            item.repository_action_log +=  log_message( "<a href=\"#{item.plan.repository_entry_edit_uri}\">Entry Edit URI</a>") if item.plan.repository_entry_edit_uri
            item.repository_action_log +=  log_message( "<a href=\"#{item.plan.repository_edit_media_uri}\">Edit Media URI</a>") if item.plan.repository_edit_media_uri
            item.repository_action_log +=  log_message( "<a href=\"#{item.plan.repository_sword_edit_uri}\">Sword Edit URI</a>") if item.plan.repository_sword_edit_uri
            item.repository_action_log +=  log_message( "<a href=\"#{item.plan.repository_sword_statement_uri}\">Sword Statement URI</a>") if item.plan.repository_sword_statement_uri
          
            item.repository_action_status_id = RepositoryActionStatus.Success_id;
            item.repository_action_log += log_message("Completed")
          else
            item.repository_action_status_id = RepositoryActionStatus.Failed_id;
            item.repository_action_log += log_message("Deposit receipt was not returned")
          end


          
        #Performing an export (with files)
        when RepositoryActionType.Export_id #, RepositoryActionType.Finalise_id
          # If the queue's repository_action_uri is set, use it, otherwise use the plan's Edit Media URI
          item.repository_action_uri ||= item.plan.repository_edit_media_uri
          item.repository_action_log +=  log_message( "<a href=\"#{item.repository_action_uri}\">Edit Media URI</a>") if item.repository_action_uri
          
          entry = Atom::Entry.new()
          entry.links.new(:href => item.repository_action_uri, :rel=>"edit-media")
          
          #Metadata should be coming from the RDF file wihin the zip-bagit file
          deposit_receipt = entry.put_media!(
            :filepath => REPOSITORY_PATH.join('queue',"#{item.id}.zip").to_s,
            :content_type => "application/zip",
            :connection => connection,
            :metadata_relevant => item.repository.filetype_rdf  #Metadata is relevant if the repository is configured to generate RDF on deposits
          )

          item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s if deposit_receipt.has_entry
          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += log_message("Completed")       

        
        
        
        when RepositoryActionType.Finalise_id
          # If the queue's repository_action_uri is set, use it, otherwise use the  plan's Sword Edit URI
          item.repository_action_uri ||= item.plan.repository_sword_edit_uri
          item.repository_action_log +=  log_message( "<a href=\"#{item.repository_action_uri}\">Sword Edit URI</a>") if item.repository_action_uri
          
          entry = Atom::Entry.new()
          deposit_receipt = entry.post!(:sword_edit_uri => item.repository_action_uri, :in_progress => false, :connection => connection)
          if deposit_receipt.has_entry
            item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s            
          end
          
          item.repository_action_status_id = RepositoryActionStatus.Success_id;
          item.repository_action_log += log_message("Completed")      


        else
          item.repository_action_status_id = RepositoryActionStatus.Failed_id;
          item.repository_action_log += log_message("Failed - no handler for requested action type #{item.repository_action_type.name}")
          
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
  
  def self.log_message(message)
    return "#{Time.now.localtime.to_s(:repository_time)}: #{message}\n" 
  end
    
end
