class CreateRepositories < ActiveRecord::Migration
  def change
    create_table :repositories do |t|
      t.references :organisation
      t.string :name
      t.string :sword_collection_uri
      t.string :username
      t.string :password
      t.string :administrator_name
      t.string :administrator_email
      
      t.boolean :create_metadata_with_new_plan

      t.boolean :filetype_rdf
      t.boolean :filetype_pdf
      t.boolean :filetype_html
      t.boolean :filetype_csv
      t.boolean :filetype_txt
      t.boolean :filetype_xml
      t.boolean :filetype_xlsx
      t.boolean :filetype_docx
      t.boolean :filetype_rtf

      t.timestamps
    end
    
    add_index :repositories, :organisation_id, :unique => true
    add_index :repositories, :name, :unique => true
    
  end
end
