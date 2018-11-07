# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Shop.create_with(display_name: 'コープデリ').find_or_create_by!(name: 'coop-deli')
Shop.create_with(display_name: 'パルシステム').find_or_create_by!(name: 'pal-system')
