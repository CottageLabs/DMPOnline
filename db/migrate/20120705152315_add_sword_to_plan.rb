class AddSwordToPlan < ActiveRecord::Migration
  def change
    add_column :plans, :duplicated_from_plan_id, :integer
    add_column :plans, :repository_id, :integer

    #Don't need collection or service document URIs for plans (they are for the Repository)
    
    add_column :plans, :repository_content_uri, :string         #Content URI / Cont-URI
    add_column :plans, :repository_entry_edit_uri, :string      #Atom Entry Edit URI / Edit-URI
    add_column :plans, :repository_edit_media_uri, :string      #Atom Edit Media URI / EM-URI
    add_column :plans, :repository_sword_edit_uri, :string      #Sword Edit URI / SE-URI
    add_column :plans, :repository_sword_statement_uri, :string #Sword Statement URI / State-URI

  end
end
