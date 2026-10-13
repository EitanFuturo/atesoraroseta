module Admin
  # The ↑ ↓ buttons: PATCH …/move with direction=up or down, one place at a time (acts_as_list).
  module Reordering
    DIRECTIONS = { "up" => :move_higher, "down" => :move_lower }.freeze

    private
      # Moves the record one place and returns the direction ("up" or "down"). Anything else is a 400.
      def move_record(record)
        direction = params.require(:direction)
        record.public_send(DIRECTIONS.fetch(direction) { raise ActionController::BadRequest, "Unknown direction" })
        direction
      end

      # The next page gives the focus back to the arrow that was pressed (Admin::RecordsHelper#admin_move_buttons),
      # so a keyboard user can press it again.
      def remember_moved(record, direction)
        flash[:moved] = "#{helpers.dom_id(record)}:#{direction}"
      end
  end
end
