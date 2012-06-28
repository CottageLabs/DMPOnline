namespace :repository do
  desc "This loads the repository queue status data; you only need to do this once when initialising the system."
  task :seed => :environment do

    RepositoryQueueStatus.create(:name => 'Initialising', :description=> 'Queue initialising, not available for processing')    
    RepositoryQueueStatus.create(:name => 'Pending', :description=> 'Awaiting processing')
    RepositoryQueueStatus.create(:name => 'Processing', :description=> 'In processing')
    RepositoryQueueStatus.create(:name => 'Failed', :description=> 'Failed processing')
    RepositoryQueueStatus.create(:name => 'Success', :description=> 'Succeeded processing')
    
  end


  desc "This processes the repository queue, run this on a scheduled basis via cron, say every ~20 minutes."
  task :process => :environment do
    RepositoryQueue.process
  end

end