import { Controller } from "@hotwired/stimulus"

// The new-artwork form: fills the web address (slug) from the title as it is typed, the way the server
// builds it ("Obra de muestra 02" → "obra-de-muestra-02"), until the slug is edited by hand. Clearing the
// slug field hands it back to the title. The server still checks it and adds -2, -3… when it is taken.
export default class extends Controller {
  static targets = [ "title", "slug" ]

  connect() {
    this.manual = this.slugTarget.value !== "" && this.slugTarget.value !== parameterize(this.titleTarget.value)
  }

  titleChanged() {
    if (!this.manual) this.slugTarget.value = parameterize(this.titleTarget.value)
  }

  slugChanged() {
    this.manual = this.slugTarget.value !== ""
  }
}

// Letters that don't decompose into a base letter plus an accent, as Rails transliterates them.
const SPECIAL_LETTERS = {
  "ß": "ss", "æ": "ae", "ø": "o", "œ": "oe", "đ": "d", "ð": "d", "þ": "th", "ł": "l"
}

// Rails' String#parameterize for Latin text: no accents, lower case, hyphens between words.
export function parameterize(text) {
  return text
    .toLowerCase()
    .replace(/[ßæøœđðþł]/g, (letter) => SPECIAL_LETTERS[letter])
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}
