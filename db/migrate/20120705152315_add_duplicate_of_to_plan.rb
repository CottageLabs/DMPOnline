class AddDuplicateOfToPlan < ActiveRecord::Migration
  def change
    add_column :plans, :duplicated_from_plan_id, :integer
  end
end
