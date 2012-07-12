class CreateRepositories < ActiveRecord::Migration
  def change
    create_table :repositories do |t|
      t.references :organisation
      t.string :name
      t.string :sword_col_uri
      t.string :username
      t.string :password
      t.string :administrator_name
      t.string :administrator_email
      
      t.boolean :create_metadata_with_new_plan

      t.boolean :deposit_pdf
      t.boolean :deposit_html
      t.boolean :deposit_csv
      t.boolean :deposit_txt
      t.boolean :deposit_xml
      t.boolean :deposit_xlsx
      t.boolean :deposit_docx
      t.boolean :deposit_rtf

      t.timestamps
    end
    
    add_index :repositories, :organisation_id, :unique => true
    add_index :repositories, :name, :unique => true
    
  end
end
