class AddSwordEditMediaUri < ActiveRecord::Migration
  def change
    add_column :phase_edition_instances, :sword_edit_media_uri, :string
  end

end
