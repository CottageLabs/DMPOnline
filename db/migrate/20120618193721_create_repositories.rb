class CreateRepositories < ActiveRecord::Migration
  def change
    create_table :repositories do |t|
      t.integer :organisation_id
      t.string :name
      t.string :collection_iri
      t.string :username
      t.string :password
      t.string :administrator_name
      t.string :administrator_email

      t.timestamps
    end
    
  end
end
