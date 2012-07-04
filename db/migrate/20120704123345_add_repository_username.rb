class AddRepositoryUsername < ActiveRecord::Migration
  def change
    add_column :users, :repository_username, :string
  end
end
