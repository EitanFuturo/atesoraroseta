# Rich text (Action Text with Lexxy: the artwork description and the Sobre mí body) on the public pages.
module RichTextHelper
  # Action Text's own rendering (sanitised, inside layouts/action_text/contents/_content), sanitised again
  # without `style` attributes. Lexxy's sanitiser allows inline styles (its highlights write colours that
  # way), but on public pages the only inline styles are the Obra tiles' sizes (overview §4.6).
  def public_rich_text(rich_text)
    sanitize rich_text.to_s, tags: sanitizer_allowed_tags, attributes: sanitizer_allowed_attributes - %w[style]
  end
end
