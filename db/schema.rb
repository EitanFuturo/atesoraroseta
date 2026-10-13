# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_13_005408) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "artwork_details", force: :cascade do |t|
    t.integer "artwork_id", null: false
    t.integer "position", null: false
    t.string "alt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artwork_id", "position"], name: "index_artwork_details_on_artwork_id_and_position"
  end

  create_table "artworks", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.integer "year"
    t.integer "year_end"
    t.string "medium"
    t.string "dimensions"
    t.boolean "published", default: false, null: false
    t.integer "position", null: false
    t.string "image_alt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_artworks_on_position"
    t.index ["slug"], name: "index_artworks_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.string "wordmark"
    t.string "nav_work_label"
    t.string "nav_torn_posters_label"
    t.string "nav_about_label"
    t.string "nav_contact_label"
    t.text "torn_posters_intro"
    t.string "details_label"
    t.string "previous_label"
    t.string "next_label"
    t.string "view_details_label"
    t.string "view_detail_one_label"
    t.string "year_label"
    t.string "medium_label"
    t.string "dimensions_label"
    t.text "seo_description"
    t.text "about_lead"
    t.string "portrait_alt"
    t.string "about_contact_link_label"
    t.string "contact_headline"
    t.string "email"
    t.string "instagram_handle"
    t.string "instagram_label"
    t.string "not_found_title"
    t.text "not_found_text"
    t.string "not_found_link_label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "torn_posters", force: :cascade do |t|
    t.string "place"
    t.string "city"
    t.integer "year"
    t.integer "year_end"
    t.string "alt"
    t.boolean "published", default: false, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_torn_posters_on_position"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "artwork_details", "artworks"
  add_foreign_key "sessions", "users"
end
