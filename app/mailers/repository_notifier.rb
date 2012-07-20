class RepositoryNotifier < ActionMailer::Base
  def report_queue_error(repository_queue_entry, exception = nil)
    @entry = repository_queue_entry
    @exception = exception
    
    mail(:to => repository_queue_entry.repository.administrator_email) 
  end
  
end
