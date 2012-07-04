class CreateRepositoryActionStatuses < ActiveRecord::Migration
  def change
    create_table :repository_action_statuses do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
    
    add_index :repository_action_statuses, :name, :unique => true
  end
end
