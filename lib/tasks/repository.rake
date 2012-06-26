namespace :repository do
  desc "This loads the repository queue status data."
  task :seed => :environment do

    RepositoryQueueStatus.create(:name => 'Initialising', :description=> 'Queue initialising, not available for processing')    
    RepositoryQueueStatus.create(:name => 'Pending', :description=> 'Awaiting processing')
    RepositoryQueueStatus.create(:name => 'Processing', :description=> 'In processing')
    RepositoryQueueStatus.create(:name => 'Failed', :description=> 'Failed processing')
    RepositoryQueueStatus.create(:name => 'Success', :description=> 'Succeeded processing')
    
  end

end