class CreateTornPosters < ActiveRecord::Migration[8.1]
  def change
    create_table :torn_posters do |t|
      t.string :place
      t.string :city
      # A single year in `year`, or a range from `year` to `year_end`.
      t.integer :year
      t.integer :year_end
      t.string :alt
      t.boolean :published, null: false, default: false
      # Set by acts_as_list on create (new photos go to the top).
      t.integer :position, null: false

      t.timestamps
    end

    add_index :torn_posters, :position
  end
end
