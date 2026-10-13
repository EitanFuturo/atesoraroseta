# The public site's menu (Obra · Torn Posters · Sobre mí · Contacto), with its labels from the settings record.
module NavigationHelper
  # [ label, path, section ] of each menu item, in the canvas's order.
  def main_menu_items
    [
      [ site.nav_work_label, root_path, :work ],
      [ site.nav_torn_posters_label, torn_posters_path, :torn_posters ],
      [ site.nav_about_label, about_path, :about ],
      [ site.nav_contact_label, contact_path, :contact ]
    ]
  end

  # The menu section the current page belongs to: Obra stays current on artwork pages, as in the canvas.
  # Nil on pages outside the menu (the 404).
  def current_section
    case controller_path
    when "artworks" then :work
    when "torn_posters" then :torn_posters
    when "pages" then { "about" => :about, "contact" => :contact }[action_name]
    end
  end
end
