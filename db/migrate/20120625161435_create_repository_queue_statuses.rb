class CreateRepositoryQueueStatuses < ActiveRecord::Migration
  def change
    create_table :repository_queue_statuses do |t|
      t.string :name
      t.string :description

      t.timestamps
    end
    
    add_index :repository_queue_statuses, :name, :unique => true
  end
end
