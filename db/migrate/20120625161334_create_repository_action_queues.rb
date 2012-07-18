class CreateRepositoryActionQueues < ActiveRecord::Migration
  def change
    create_table :repository_action_queues do |t|
      t.references  :repository
      t.references  :plan
      t.references  :phase_edition_instance
      t.references  :user
      t.references  :repository_action_type
      t.references  :repository_action_status
      t.string      :repository_action_uri # it is necessary to store the URI on which to perform the action in the queue table, to handle the eventuality when the action is to delete from the repository something which has already been deleted from DMPOnline
      t.string      :repository_action_receipt
      t.text        :repository_action_log #This field can get quite long
      t.integer     :retry_count
      t.timestamps
    end
    
    add_index :repository_action_queues, :repository_id, :unique => false
    add_index :repository_action_queues, :phase_edition_instance_id, :unique => false
    add_index :repository_action_queues, :repository_action_status_id, :unique => false
     
  end
end
