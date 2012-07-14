ActiveAdmin.register Repository do
  
  # Limit list according to access rights
  scope_to :current_user

  filter :name  
  filter :organisation
  filter :sword_collection_uri
  
  controller.authorize_resource

  form :partial => "form"  

   index do
     column :name
     column :organisation
     column "Collection IRI", :sword_collection_uri
     column :username
     column :administrator_email
     column "Create Metadata" do |r|
       check_box_tag :create_metadata_with_new_plan, 1, r.create_metadata_with_new_plan, :disabled=>true
     end
     default_actions
   end
   
   
   show :title => :name do |repository|
     filetypes = [:rdf, :pdf, :html, :csv, :txt, :xml, :xlsx, :docx, :rtf]
     render :partial=>"show", :locals => {:repository => repository, :filetypes => filetypes}
  end
 
 
end
