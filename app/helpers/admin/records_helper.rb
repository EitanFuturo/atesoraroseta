module Admin
  # Badges, "Ver en la web" links and ↑ ↓ buttons for artworks, details and posters.
  module RecordsHelper
    MOVE_ARROWS = { "up" => "↑", "down" => "↓" }.freeze

    # "Publicada" or "Borrador".
    def admin_published_badge(record)
      if record.published?
        tag.span t("admin.records.published"), class: "badge badge--published"
      else
        tag.span t("admin.records.draft"), class: "badge badge--draft"
      end
    end

    # "Ver en la web ↗" in a new tab. An unpublished record that a logged-in admin can preview (an
    # artwork) links to its preview; one that has no public place yet (a poster) is greyed out, unlinked.
    def admin_view_on_site_link(path, published: true, previewable: true)
      if published
        admin_external_link t("admin.shared.view_on_site"), path
      elsif previewable
        admin_external_link t("admin.shared.preview_on_site"), path
      else
        tag.span t("admin.shared.unpublished_on_site"), class: "view-on-site--unpublished"
      end
    end

    # ↑ ↓ for one record of a list, each a small form of its own (PATCH path with direction=up|down). Screen
    # readers hear "Subir <name> un puesto". After a move, the arrow that was pressed has the focus again
    # (or the other one, when the record reached the end of the list).
    #
    # form: the id of a form to send instead (form="…"), for buttons inside another form, which can't nest.
    def admin_move_buttons(record, path:, name:, first:, last:, form: nil)
      disabled = { "up" => first, "down" => last }
      focused = admin_moved_direction(record, disabled)

      tag.div class: "move-buttons" do
        safe_join(MOVE_ARROWS.keys.map do |direction|
          label = safe_join([ tag.span(MOVE_ARROWS[direction], aria: { hidden: true }),
            tag.span(t("admin.shared.move.#{direction}", name: name), class: "visually-hidden") ])
          options = { class: "button button--secondary button--small", disabled: disabled[direction],
            title: t("admin.shared.move.#{direction}_title"), autofocus: (true if focused == direction) }

          if form
            tag.button(label, type: "submit", form: "#{form}-#{direction}", **options)
          else
            button_to path, method: :patch, params: { direction: direction }, **options do
              label
            end
          end
        end)
      end
    end

    # The small forms behind admin_move_buttons(form: …), rendered outside the form the buttons sit in.
    def admin_move_forms(path:, form:)
      safe_join(MOVE_ARROWS.keys.map do |direction|
        form_with url: path, method: :patch, id: "#{form}-#{direction}", html: { hidden: true } do
          hidden_field_tag :direction, direction, id: nil
        end
      end)
    end

    private
      # The direction whose button gets the focus back after this record was moved, if it was.
      def admin_moved_direction(record, disabled)
        id, direction = flash[:moved].to_s.split(":")
        return unless id == dom_id(record) && MOVE_ARROWS.key?(direction)

        disabled[direction] ? MOVE_ARROWS.keys.find { |other| !disabled[other] } : direction
      end
  end
end
