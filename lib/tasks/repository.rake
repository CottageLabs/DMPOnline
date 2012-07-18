namespace :repository do
  desc "This loads the repository reference data; you only need to do this once when initialising the system."
  task :seed => :environment do

    RepositoryActionStatus.create!([
      {:name => 'Initialising', :description => 'Action initialising, not yet available for processing'},
      {:name => 'Pending', :description => 'Awaiting processing'},
      {:name => 'Processing', :description => 'In processing'},
      {:name => 'Failed - Requeue', :description => 'Failed processing, will automatically requeue and try again'},
      {:name => 'Failed - Terminated', :description => 'Failed processing, terminated action and will not try again'},
      {:name => 'Success', :description => 'Succeeded processing'}
    ])


    RepositoryActionType.create!([
      {:name => 'Create Metadata', :description =>'Create a metadata record in repository'},
      {:name => 'Create Metadata and Media', :description =>'Create a metadata and media record in repository'},
      {:name => 'Replace Media', :description =>'Replace (put) the existing media record'},
      {:name => 'Add Media', :description =>'Add (post) to the existing media record'},
      {:name => 'Finalise', :description =>'Finalise record in repository'},
      {:name => 'Duplicate', :description =>'Duplicate in repository'},
      {:name => 'Delete', :description =>'Delete record from repository'}
    ])

    
  end


  desc "This processes the repository action queue, run this on a scheduled basis via cron, say every ~20 minutes."
  task :process => :environment do
    RepositoryActionQueue.process
  end

end