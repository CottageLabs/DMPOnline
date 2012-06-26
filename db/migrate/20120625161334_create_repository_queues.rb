class CreateRepositoryQueues < ActiveRecord::Migration
  def change
    create_table :repository_queues do |t|
      t.references :repository
      t.references :plan
      t.references :phase_edition_instance
      t.references :user
      t.datetime :submitted_date
      t.references :repository_queue_status
      t.datetime :status_date
      t.string :log

      t.timestamps
    end
    
    add_index :repository_queues, :repository_id, :unique => false
    add_index :repository_queues, :repository_queue_status_id, :unique => false
    add_index :repository_queues, :submitted_date, :unique => false
     
  end
end
