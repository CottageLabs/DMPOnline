# encoding: UTF-8

include Rails.application.routes.url_helpers

OrganisationType.create(:title => 'Funding Bodies')
institution = OrganisationType.create(:title => 'Institutions')
OrganisationType.create(:title => 'Disciplines')
 
dcc = Organisation.create(
  :full_name => "Digital Curation Centre",
  :short_name => "DCC",
  :domain => "dcc.ac.uk",
  :url => "www.dcc.ac.uk",
  :default_locale => 'en'
)

org = Organisation.create(
  :full_name => "The University of Edinburgh",
  :short_name => "UoE",
  :domain => "ed.ac.uk",
  :url => "www.ed.ac.uk",
  :organisation_type => institution,
  :default_locale => 'en'
)

t = Template.create(
  :organisation_id => dcc.id,
  :name => "DCC Checklist",
  :phases_attributes => [{:phase => "Checklist", :position => 1 }]
) 
t.make_checklist(dcc.id)

Page.create([
  {
    :title => "Welcome to the DMPOnline",
    :body => "This is the default homepage",
    :slug => "home",
    :position => 0,
    :menu => Page::MENU.index('none'),
    :organisation_id => dcc.id
  },
  {
    :title => "Privacy Statement/Terms of Use",
    :body => "<p>This software is made available under ... licence.</p><p>No warranty...</p>",
    :slug => "terms",
    :position => 1,
    :menu => Page::MENU.index('help'),
    :organisation_id => dcc.id
  },
  {
    :title => "Help",
    :body => "<p>dmponline@dcc.ac.uk</p>",
    :slug => "help",
    :position => 2,
    :menu => Page::MENU.index('help'),
    :organisation_id => dcc.id
  },
  {
    :title => "Home",
    :menu => Page::MENU.index('navigation'),
    :position => -10,
    :target_url => root_path,
    :organisation_id => dcc.id
  },
  {
    :title => "My Plans",
    :menu => Page::MENU.index('navigation'),
    :position => 10,
    :target_url => plans_path,
    :organisation_id => dcc.id
  },
  {
    :title => "Shared Plans",
    :menu => Page::MENU.index('navigation'),
    :position => 10,
    :target_url => shared_plans_path,
    :organisation_id => dcc.id
  }
])

Currency.create([
  {
    :name => "Pound Sterling",
    :symbol => "£",
    :iso_code => "GBP"
  },
  {
    :name => "Euro",
    :symbol => "€",
    :iso_code => "EUR"
  }
])

user = User.new
user.send :attributes=, {:email => 'admin@example.com', :password => 'password', :password_confirmation => 'password', :confirmed_at => Time.current}, false
user.save!

role = Role.new
role.user_id = user.id
role.assigned= :sysadmin
role.save!

user = User.new
user.send :attributes=, {:email => 'dcc@example.com', :password => 'password', :password_confirmation => 'password', :confirmed_at => Time.current}, false
user.save!

role = Role.new
role.user_id = user.id
role.assigned= :dccadmin
role.save!

user = User.new
user.send :attributes=, {:email => 'organisation@example.com', :password => 'password', :password_confirmation => 'password', :confirmed_at => Time.current}, false
user.save!

role = Role.new
role.user_id = user.id
role.organisation_id = org.id
role.assigned= :orgadmin
role.save!

user = User.new
user.send :attributes=, {:email => 'user@example.com', :password => 'password', :password_confirmation => 'password', :confirmed_at => Time.current}, false
user.save!


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
  {:name => 'Duplicate', :description =>'Duplicate in repository'},
  {:name => 'Delete', :description =>'Delete record from repository'}
])

Repository.create!([
  {
    :name => "SimpleSword DCC Repo",
    :organisation_id => 1, 
    :sword_collection_uri => "http://localhost:8080/col-uri/dcc-collection", 
    :username => "sword", 
    :password => "sword",
    :administrator_name => "Administrator",
    :administrator_email => "admin@example.com",
    :create_metadata_with_new_plan => true,
    :filetype_rdf => true,
    :filetype_pdf => true,
    :filetype_csv => true,
    :filetype_txt => true
  },
  {
    :name => "SimpleSword Edinburgh Repo",
    :organisation_id => 2, 
    :sword_collection_uri => "http://localhost:8080/col-uri/edinburgh-collection", 
    :username => "sword", 
    :password => "sword",
    :administrator_name => "Administrator",
    :administrator_email => "admin@example.com",
    :create_metadata_with_new_plan => true,
    :filetype_rdf => true,
    :filetype_pdf => true,
    :filetype_docx => true,
    :filetype_xlsx => true
  }
])