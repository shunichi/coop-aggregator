class AddParentToItems < ActiveRecord::Migration[5.2]
  def change
    add_column :items, :parent_id, :bigint
    add_index :items, :parent_id
    add_foreign_key :items, :items, column: :parent_id
  end
end
