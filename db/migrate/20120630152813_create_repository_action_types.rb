class CreateRepositoryActionTypes < ActiveRecord::Migration
  def change
    create_table :repository_action_types do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
    
    add_index :repository_action_types, :name, :unique => true
  end
end
