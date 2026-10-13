// The admin's JavaScript (only the admin layout loads the import map; public pages ship no JavaScript).
// Configure your import map in config/importmap.rb.
import "@hotwired/turbo-rails"
import "controllers"
import * as ActiveStorage from "@rails/activestorage"
import { configure as configureLexxy } from "lexxy"

// Image fields upload each file straight to Active Storage, one request per file, before the form is sent.
ActiveStorage.start()

// The rich text editor (artwork descriptions and the Sobre mí text). The public pages style paragraphs,
// bold, italic and links, so the editor keeps to those:
// - no attachments (images belong in the image fields);
// - no Markdown shortcuts, which would turn "- " or "# " into lists and headings;
// - no colour highlights, which Lexxy writes as inline style attributes: with no colours offered or
//   permitted, pasted colours are dropped too.
// Lexxy defines its elements after a timeout, so this runs before any editor starts.
configureLexxy({
  default: {
    attachments: false,
    markdown: false,
    highlight: {
      buttons: { color: [], "background-color": [] },
      permit: { color: [], "background-color": [] }
    }
  }
})
