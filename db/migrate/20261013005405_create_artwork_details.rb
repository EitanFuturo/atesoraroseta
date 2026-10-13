class CreateArtworkDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :artwork_details do |t|
      # The composite index below also serves the foreign key.
      t.references :artwork, null: false, foreign_key: true, index: false
      # Set by acts_as_list on create (new details go to the end of their artwork's list).
      t.integer :position, null: false
      t.string :alt

      t.timestamps
    end

    add_index :artwork_details, [ :artwork_id, :position ]
  end
end
