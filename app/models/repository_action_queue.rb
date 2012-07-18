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
  def self.latest_entries_any_phase(repository, plan = nil, limit = REPOSITORY_LOG_LENGTH)
    conditions = {:repository_id => repository.id}
    conditions[:plan_id] = plan.id if plan
    
    all(  :conditions => conditions,
          :limit => limit, 
          :order=>"id desc", 
          :include=>[:repository_action_status, :repository_action_type, :user, :plan, :phase_edition_instance] )
  end
  
  def self.latest_entry_by_phase(repository, plan, phase_edition_instance)
    conditions = {:repository_id => repository.id}
    conditions[:plan_id] = plan.id
    conditions[:phase_edition_instance_id] = phase_edition_instance.nil? ? nil : phase_edition_instance.id

    first(  :conditions => conditions,
            :order=>"id desc", 
            :include=>[:repository_action_status, :repository_action_type, :user, :plan, :phase_edition_instance] )
  end
  
  def self.has_deposited_media?(repository, plan, phase_edition_instance)
    conditions = {:repository_id => repository.id}
    conditions[:plan_id] = plan.id
    conditions[:phase_edition_instance_id] = phase_edition_instance.nil? ? nil : phase_edition_instance.id
    conditions[:repository_action_type_id] = [RepositoryActionType.Create_Metadata_Media_id, RepositoryActionType.Replace_Media_id, RepositoryActionType.Add_Media_id]
     
    exists?(conditions)
  end

  def self.has_deposited_metadata?(repository, plan)
      conditions = {:repository_id => repository.id}
      conditions[:plan_id] = plan.id
      conditions[:repository_action_type_id] = [RepositoryActionType.Create_Metadata_id, RepositoryActionType.Create_Metadata_Media_id, RepositoryActionType.Duplicate_id]

      exists?(conditions)
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
    
    logger.info "Processing the repository queue."
    queue_items = self.all(
      :conditions=> {:repository_action_status_id=>RepositoryActionStatus.Pending_id},
      :order=>"id asc") #first in, first out
    logger.info "There are #{queue_items.count} item(s) in the queue to process"
      
    queue_items.each do |item|      
      logger.info "Processing #{item.id}"

      deposit_receipt = nil #clear out previous receipt

      #record item as being processed
      item.repository_action_status_id = RepositoryActionStatus.Processing_id;
      item.repository_action_log +=  log_message("Processing")
      item.save!
      

      logger.info "Getting connection to repository with on_behalf_of username"
      connection = item.repository.get_connection(item.user.repository_username)

      media_filepath = REPOSITORY_PATH.join('queue',"#{item.id}.zip").to_s
      media_exists = File.exists?(media_filepath)
      media_content_type = "application/zip"



      #Now process the queue acording to the type
      case item.repository_action_type_id
      
        # Creating a metadata only record (no files)
        # Creating a metadata + files record
        # Duplicating a record
        when RepositoryActionType.Create_Metadata_id, RepositoryActionType.Create_Metadata_Media_id, RepositoryActionType.Duplicate_id
          
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
          
          if (item.repository_action_type_id == RepositoryActionType.Create_Metadata_Media_id)
             if (media_exists)
                deposit_receipt = collection.post_multipart!(:entry=>entry, :slug=>slug, :in_progress => true, :filepath => media_filepath, :content_type => media_content_type)
              else
                #Throw an error - requested an create with media but the media could not be found
                raise "Media file #{media_filepath} could not be found. Check value of REPOSITORY_PATH in config/initializers/repository.config"
              end
          else
              deposit_receipt = collection.post!(:entry=>entry, :slug=>slug, :in_progress=>true)
          end
          
         
          
          if (deposit_receipt && deposit_receipt.has_entry)
            item.plan.repository_content_uri = deposit_receipt.entry.content.src if deposit_receipt.entry.content && deposit_receipt.entry.content.src
            item.plan.repository_entry_edit_uri = deposit_receipt.entry.entry_edit_uri if deposit_receipt.entry.entry_edit_uri
            item.plan.repository_edit_media_uri = deposit_receipt.entry.edit_media_links.first.href if deposit_receipt.entry.edit_media_links.length > 0
            item.plan.repository_sword_edit_uri = deposit_receipt.entry.sword_edit_uri if deposit_receipt.entry.sword_edit_uri
            item.plan.repository_sword_statement_uri = deposit_receipt.entry.sword_statement_links.first.href if deposit_receipt.entry.sword_statement_links.length > 0
            
            item.plan.save!
            
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
        when RepositoryActionType.Replace_Media_id, RepositoryActionType.Add_Media_id
          # If the queue's repository_action_uri is set, use it, otherwise use the plan's Edit Media URI
          item.repository_action_uri ||= item.plan.repository_edit_media_uri
          item.repository_action_log +=  log_message( "<a href=\"#{item.repository_action_uri}\">Edit Media URI</a>") if item.repository_action_uri
          
          entry = Atom::Entry.new()
          entry.links.new(:href => item.repository_action_uri, :rel=>"edit-media")
          
          #Metadata should be coming from the RDF file wihin the zip-bagit file
          
          if (media_exists)
            
            if (item.repository_action_type_id == RepositoryActionType.Replace_Media_id)
              deposit_receipt = entry.put_media!(
                :filepath => media_filepath, :content_type => media_content_type,
                :connection => connection,
                :metadata_relevant => item.repository.filetype_rdf  #Metadata is relevant if the repository is configured to generate RDF on deposits
              )
            else
              #Post (add)
              deposit_receipt = entry.post_media!(
                :filepath => media_filepath, :content_type => media_content_type,
                :connection => connection,
                :metadata_relevant => item.repository.filetype_rdf  #Metadata is relevant if the repository is configured to generate RDF on deposits
              )
            end
            
            item.repository_action_receipt = deposit_receipt.entry.to_xml.to_s if deposit_receipt.has_entry
            
          else
            #Throw an error - requested an export but the media could not be found
            raise "Media file #{media_filepath} could not be found. Check value of REPOSITORY_PATH in config/initializers/repository.config"            
          end
          
          
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
