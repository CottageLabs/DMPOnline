module Dmponline3
  class Application < Rails::Application

    # Set the list of locales that we will support here (ie those for which we have translations for the DMPOnline application)
    # config.supported_locales = ['en', 'pl', 'ro']
    config.supported_locales = ['en']
    # config.middleware.use "DetermineLocale", config.supported_locales

    # Do we want to use reCaptcha for user sign-up or not
    # As default this is disabled since we already have email address confirmation
    config.recaptcha_enabled = false
    
    # Enable shibboleth as an alternative authentication method
    # Requires server configuration and omniauth shibboleth provider configuration
    # See config/initializers/omniauth.rb
    config.shibboleth_enabled = false
    
    # Absolute path to Shibboleth SSO Login
    config.shibboleth_login = '/Shibboleth.sso/Login'
    
    # Supported export formats.  If you don't want to offer a particular format, 
    # you can remove it from this list
    # :ttl is Turtle (RDF) format: http://www.w3.org/TeamSubmission/turtle/
    config.export_formats = [:pdf, :html, :csv, :txt, :xml, :xlsx, :docx, :rtf, :ttl] 


    # Repository submission settings:
    
    # Set the path to the repository folder, used for queueing operations, e.g.
    config.repository_path = Rails.root.join('repository')
    # Maximum number of log entries to display
    config.repository_log_length = 100
    # How many times should the system attempt to post to a repository before giving up
    config.repository_queue_retries = 3
    # You must change this to a key of your own
    config.repository_key = "Your encryption string for repository credentials goes here"
    # Required from address for all emails sent to repository admins as notification of queue failure
    config.repository_notifications_from = "dmponline@example.org"

  end
end
