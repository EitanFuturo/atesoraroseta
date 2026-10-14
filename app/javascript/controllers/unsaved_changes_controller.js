import { Controller } from "@hotwired/stimulus"

// Warns before unsaved changes are lost, on pages whose forms are sent separately: typing in one form and
// then sending another one (an ↑ ↓ or Eliminar button, an upload, "Cerrar sesión") or following a link
// would reload the page without those changes. Sending the changed form itself never asks.
//
//   <div data-controller="unsaved-changes" data-unsaved-changes-message-value="…">
//     <form data-unsaved-changes-main …>   the form that holds the page's fields
//
// After a failed save the page comes back with the typed values, still unsaved: render it with
// data-unsaved-changes-dirty-value="true" and the main form counts as changed from the start.
export default class extends Controller {
  static values = { message: String, dirty: Boolean }

  connect() {
    this.changedForms = new Set()
    if (this.dirtyValue) {
      this.element.querySelectorAll("form[data-unsaved-changes-main]").forEach((form) => this.changedForms.add(form))
    }

    this.track = this.track.bind(this)
    this.rememberEditor = this.rememberEditor.bind(this)
    this.trackEditor = this.trackEditor.bind(this)
    this.confirmSubmit = this.confirmSubmit.bind(this)
    this.confirmVisit = this.confirmVisit.bind(this)
    this.warnBeforeUnload = this.warnBeforeUnload.bind(this)

    this.element.addEventListener("input", this.track)
    this.element.addEventListener("change", this.track)
    this.element.addEventListener("lexxy:initialize", this.rememberEditor)
    this.element.addEventListener("lexxy:change", this.trackEditor)
    // On window, in the capture phase: the question comes before Active Storage starts uploading (it
    // listens on document) and before Turbo sends the form.
    window.addEventListener("submit", this.confirmSubmit, true)
    document.addEventListener("turbo:before-visit", this.confirmVisit)
    window.addEventListener("beforeunload", this.warnBeforeUnload)
  }

  disconnect() {
    this.element.removeEventListener("input", this.track)
    this.element.removeEventListener("change", this.track)
    this.element.removeEventListener("lexxy:initialize", this.rememberEditor)
    this.element.removeEventListener("lexxy:change", this.trackEditor)
    window.removeEventListener("submit", this.confirmSubmit, true)
    document.removeEventListener("turbo:before-visit", this.confirmVisit)
    window.removeEventListener("beforeunload", this.warnBeforeUnload)
  }

  track(event) {
    const form = event.target.form
    if (form) this.changedForms.add(form)
  }

  // Lexxy may tidy the stored HTML as it starts; only a real edit counts.
  rememberEditor(event) {
    event.target.dataset.initialValue = event.target.value
  }

  trackEditor(event) {
    const editor = event.target
    if (editor.dataset.initialValue !== undefined && editor.value !== editor.dataset.initialValue) {
      this.track({ target: editor })
    }
  }

  confirmSubmit(event) {
    const others = this.#changedFormsOtherThan(event.target)

    if (others.length > 0 && !window.confirm(this.messageValue)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    } else {
      // The answer to this form replaces the page.
      this.changedForms.clear()
    }
  }

  confirmVisit(event) {
    if (this.#changedFormsOtherThan(null).length > 0 && !window.confirm(this.messageValue)) {
      event.preventDefault()
    } else {
      this.changedForms.clear()
    }
  }

  warnBeforeUnload(event) {
    if (this.#changedFormsOtherThan(null).length > 0) {
      event.preventDefault()
      event.returnValue = ""
    }
  }

  // Private

  #changedFormsOtherThan(form) {
    return Array.from(this.changedForms).filter((changed) => changed !== form && changed.isConnected)
  }
}
