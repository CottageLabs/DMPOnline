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

      t.timestamps
    end
    
    add_index :repositories, :organisation_id, :unique => true
    add_index :repositories, :name, :unique => true
    
  end
end
