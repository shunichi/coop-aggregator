# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2018_11_22_021602) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "deliveries", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.date "delivery_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_deliveries_on_shop_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "delivery_id", null: false
    t.string "name", null: false
    t.integer "price", default: 0, null: false
    t.integer "quantity", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.string "image_url"
    t.index ["delivery_id"], name: "index_items_on_delivery_id"
    t.index ["parent_id"], name: "index_items_on_parent_id"
  end

  create_table "shops", force: :cascade do |t|
    t.string "name", null: false
    t.string "display_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "deliveries", "shops"
  add_foreign_key "items", "deliveries"
  add_foreign_key "items", "items", column: "parent_id"
end
