class AddFieldsToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :create_metadata_with_new_plan, :boolean

    add_column :repositories, :deposit_pdf, :boolean
    add_column :repositories, :deposit_html, :boolean
    add_column :repositories, :deposit_csv, :boolean
    add_column :repositories, :deposit_txt, :boolean
    add_column :repositories, :deposit_xml, :boolean
    add_column :repositories, :deposit_xlsx, :boolean
    add_column :repositories, :deposit_docx, :boolean
    add_column :repositories, :deposit_rtf, :boolean
    
    

  end
end
