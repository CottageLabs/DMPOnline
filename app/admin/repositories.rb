ActiveAdmin.register Repository do
  
  # Limit list according to access rights
  scope_to :current_user

  filter :name  
  filter :organisation
  filter :sword_col_uri
  
  controller.authorize_resource
  

 index do
   column :name
   column :organisation
   column "Collection IRI", :sword_col_uri
   column :username
   column :administrator_name
   column :administrator_email
   default_actions
 end
 
 show :title => :name do |repository|
   attributes_table do
     row :name
     row :organisation
     row :sword_col_uri
     row :username
     row :administrator_name
     row :administrator_email
     
     row :show_log
     
   end
 end
 
end
