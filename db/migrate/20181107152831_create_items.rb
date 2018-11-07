class CreateItems < ActiveRecord::Migration[5.2]
  def change
    create_table :items do |t|
      t.references :delivery, foreign_key: true, null: false
      t.string :name, null: false
      t.integer :price, null: false, default: 0
      t.integer :quantity, null: false, default: 0
      t.integer :total, null: false, default: 0

      t.timestamps
    end
  end
end
