ActiveAdmin.register Repository do
  
  # Limit list according to access rights
  scope_to :current_user

  filter :name  
  filter :organisation
  filter :collection_iri
  
  controller.authorize_resource
  

 index do
   column :name
   column :organisation
   column "Collection IRI", :collection_iri
   column :username
   column :administrator_name
   column :administrator_email
   default_actions
 end
 
 show :title => :name do |repository|
   attributes_table do
     row :name
     row :organisation
     row :collection_iri
     row :username
     row :administrator_name
     row :administrator_email
     
   end
 end
 
end
