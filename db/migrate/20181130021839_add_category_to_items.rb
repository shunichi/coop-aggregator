class AddCategoryToItems < ActiveRecord::Migration[5.2]
  def change
    add_column :items, :category, :string, null: false, default: 'none'
  end
end
