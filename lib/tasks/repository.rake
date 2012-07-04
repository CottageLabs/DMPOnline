namespace :repository do
  desc "This loads the repository reference data; you only need to do this once when initialising the system."
  task :seed => :environment do

    RepositoryActionStatus.create!([
      {:name => 'Initialising', :description => 'Action initialising, not yet available for processing'},
      {:name => 'Pending', :description => 'Awaiting processing'},
      {:name => 'Processing', :description => 'In processing'},
      {:name => 'Failed', :description => 'Failed processing'},
      {:name => 'Success', :description => 'Succeeded processing'}
    ])


    RepositoryActionType.create!([
      {:name => 'Create', :description =>'Create record in repository'},
      {:name => 'Export', :description =>'Export record to repository'},
      {:name => 'Finalise', :description =>'Finalise record in repository'},
      {:name => 'Delete', :description =>'Delete record from repository'}
    ])

    Repository.create!([
      {
        :name => "SimpleSword DCC Repo",
        :organisation_id => 1, 
        :sword_col_uri => "http://localhost:8080/col-uri/dcc-collection", 
        :username => "sword", 
        :password => "sword",
        :administrator_name => "Administrator",
        :administrator_email => "admin@example.com"
      },
      {
        :name => "SimpleSword Edinburgh Repo",
        :organisation_id => 2, 
        :sword_col_uri => "http://localhost:8080/col-uri/edinburgh-collection", 
        :username => "sword", 
        :password => "sword",
        :administrator_name => "Administrator",
        :administrator_email => "admin@example.com"
      }
    ])
    
  end


  desc "This processes the repository action queue, run this on a scheduled basis via cron, say every ~20 minutes."
  task :process => :environment do
    RepositoryActionQueue.process
  end

end