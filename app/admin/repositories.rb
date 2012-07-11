ActiveAdmin.register Repository do
  
  # Limit list according to access rights
  scope_to :current_user

  filter :name  
  filter :organisation
  filter :sword_col_uri
  
  controller.authorize_resource

  form :partial => "form"  

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
       row :sword_col_uri do
         link_to repository.sword_col_uri, repository.sword_col_uri, :target=>"_blank"
       end
       row :username
       row :administrator_name
       row :administrator_email

       row t('repository.automatic_metadata_deposit') do
         check_box_tag :create_metadata_with_new_plan, 1, repository.create_metadata_with_new_plan, :disabled=>true
       end
     end
     
     panel I18n.t('repository.automatic_deposit_types') do
       attributes_table_for(repository) do
         row t('repository.deposit_pdf') do
           check_box_tag :deposit_pdf, 1, repository.deposit_pdf, :disabled=>true
         end
         row t('repository.deposit_html') do
           check_box_tag :deposit_html, 1, repository.deposit_html, :disabled=>true
         end
         row t('repository.deposit_csv') do
           check_box_tag :deposit_csv, 1, repository.deposit_csv, :disabled=>true
         end
         row t('repository.deposit_txt')  do
           check_box_tag :deposit_txt, 1, repository.deposit_txt, :disabled=>true
         end
         row t('repository.deposit_xml')  do
           check_box_tag :deposit_xml, 1, repository.deposit_xml, :disabled=>true
         end
         row t('repository.deposit_xlsx')  do
           check_box_tag :deposit_xlsx, 1, repository.deposit_xlsx, :disabled=>true
         end
         row t('repository.deposit_docx')  do
           check_box_tag :deposit_docx, 1, repository.deposit_docx, :disabled=>true
         end
         row t('repository.deposit_rtf') do
           check_box_tag :deposit_rtf, 1, repository.deposit_rtf, :disabled=>true
         end
       end
     end
     
     panel I18n.t('repository.actions_log') do
       table_for(repository.show_log[:entries]) do
         column(:created_at, :sortable) {|entry| entry.created_at}
         column(:plan) {|entry| entry.plan.project}
         column(:repository_action_type) {|entry| entry.repository_action_type.name}
         column(:repository_action_status) {|entry| entry.repository_action_status.name}
         column(:user) {|entry| entry.user.email}
         column(:repository_action_log) {|entry| simple_format(entry.repository_action_log)}
       end
     end
       
   end
 
#   show :title => :name do |repository|
#     render "show"
#   end
=begin     
     attributes_table do       
    

       row :deposit_pdf
       row :deposit_html
       row :deposit_csv
       row :deposit_txt
       row :deposit_xml
       row :deposit_xlsx
       row :deposit_docx
       row :deposit_rtf
       
       row :show_log
     
     end
    
   end
=end
 
end

# <fieldset class="buttons"><ol>
#  <li class="commit button"><input class="create" id="repository_submit" name="commit" type="submit" value="Create Repository" /></li>
#  <li class="cancel"><a href="/admin/repositories">Cancel</a></li>
# </ol></fieldset>