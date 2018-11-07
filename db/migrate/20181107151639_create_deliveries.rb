class CreateDeliveries < ActiveRecord::Migration[5.2]
  def change
    create_table :deliveries do |t|
      t.references :shop, foreign_key: true, null: false
      t.string :name, null: false
      t.date :delivery_date

      t.timestamps
    end
  end
end
