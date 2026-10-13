class CreateArtworks < ActiveRecord::Migration[8.1]
  def change
    create_table :artworks do |t|
      t.string :title, null: false
      t.string :slug, null: false
      # A single year in `year`, or a range from `year` to `year_end`.
      t.integer :year
      t.integer :year_end
      t.string :medium
      t.string :dimensions
      t.boolean :published, null: false, default: false
      # Set by acts_as_list on create (new works go to the top).
      t.integer :position, null: false
      t.string :image_alt

      t.timestamps
    end

    add_index :artworks, :slug, unique: true
    add_index :artworks, :position
  end
end
