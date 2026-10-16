import { Controller } from "@hotwired/stimulus"

// An image file field with Active Storage direct uploads, for one file or several.
//
// When files are chosen, it drops those over the size limit or of a type the server won't take (each with
// a message), keeps the rest and lists them. When the form is sent, Active Storage uploads each file in its
// own request; this shows each file's progress on its line. The server checks everything again.
//
//   <div data-controller="upload" data-upload-max-bytes-value="52428800"
//        data-upload-accept-value="image/jpeg,image/png,image/webp" data-upload-messages-value="{…}"
//        data-action="direct-upload:initialize->upload#register direct-upload:start->upload#start
//                     direct-upload:progress->upload#progress direct-upload:error->upload#error
//                     direct-upload:end->upload#end">
//     <input type="file" data-upload-target="input" data-action="upload#check" data-direct-upload-url="…">
//     <p data-upload-target="errors" role="alert"></p>
//     <ul data-upload-target="list" aria-live="polite"></ul>
//   </div>
//
// Messages (Spanish, from the locale) use %{name}, %{size} and %{max}: tooLarge, wrongType, ready,
// uploading, done and failed.
export default class extends Controller {
  static targets = [ "input", "list", "errors" ]
  static values = { maxBytes: Number, accept: String, messages: Object }

  disconnect() {
    this.#revokePreviews()
  }

  // The files were chosen: keep the acceptable ones and list them.
  check() {
    const files = Array.from(this.inputTarget.files)
    const accepted = []
    const errors = []

    files.forEach((file) => {
      if (file.size > this.maxBytesValue) {
        errors.push(this.#message("tooLarge", { name: file.name, size: this.#megabytes(file.size) }))
      } else if (file.type && !this.#acceptedTypes.includes(file.type)) {
        errors.push(this.#message("wrongType", { name: file.name }))
      } else {
        accepted.push(file)
      }
    })

    if (accepted.length !== files.length) this.#keepOnly(accepted)
    this.#showErrors(errors)
    this.#list(accepted)
  }

  // Active Storage created the upload for a file (not Stimulus' initialize(): this is an action).
  register(event) {
    const { file, id } = event.detail
    const line = this.#lineFor(file) || this.#appendLine(file)
    line.dataset.uploadId = id
  }

  start(event) {
    this.#update(event.detail.id, { status: this.#message("uploading") })
  }

  progress(event) {
    const line = this.#lineById(event.detail.id)
    if (line) line.querySelector("progress").value = event.detail.progress
  }

  error(event) {
    // Show the problem on the file's line instead of Active Storage's English alert.
    event.preventDefault()
    this.#update(event.detail.id, { status: this.#message("failed", { name: event.detail.file.name }), state: "error" })
  }

  end(event) {
    const line = this.#lineById(event.detail.id)
    if (!line || line.dataset.state === "error") return

    line.querySelector("progress").value = 100
    this.#update(event.detail.id, { status: this.#message("done"), state: "done" })
  }

  // Private

  get #acceptedTypes() {
    return this.acceptValue.split(",").map((type) => type.trim()).filter(Boolean)
  }

  #keepOnly(files) {
    const transfer = new DataTransfer()
    files.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
  }

  #showErrors(errors) {
    if (!this.hasErrorsTarget) return

    this.errorsTarget.replaceChildren(...errors.map((text) => {
      const line = document.createElement("span")
      line.className = "upload-errors__line"
      line.textContent = text
      return line
    }))
  }

  #list(files) {
    if (!this.hasListTarget) return

    this.#revokePreviews()
    this.listTarget.replaceChildren(...files.map((file) => this.#buildLine(file)))
  }

  #appendLine(file) {
    const line = this.#buildLine(file)
    if (this.hasListTarget) this.listTarget.append(line)
    return line
  }

  #buildLine(file) {
    const line = document.createElement("li")
    line.dataset.key = this.#key(file)

    const preview = document.createElement("img")
    preview.className = "uploads__preview"
    preview.alt = ""
    preview.src = URL.createObjectURL(file)
    this.previews = [ ...(this.previews || []), preview.src ]

    const name = document.createElement("span")
    name.className = "uploads__name"
    name.textContent = file.name

    const progress = document.createElement("progress")
    progress.max = 100
    progress.value = 0
    progress.setAttribute("aria-hidden", "true")

    const status = document.createElement("span")
    status.className = "uploads__status"
    status.textContent = this.#message("ready")

    line.append(preview, name, progress, status)
    return line
  }

  #update(id, { status, state }) {
    const line = this.#lineById(id)
    if (!line) return

    if (state) {
      line.dataset.state = state
      line.querySelector(".uploads__status").className = `uploads__status uploads__status--${state}`
    }
    line.querySelector(".uploads__status").textContent = status
  }

  #lineFor(file) {
    if (!this.hasListTarget) return null
    return Array.from(this.listTarget.children).find((line) => line.dataset.key === this.#key(file) && !line.dataset.uploadId)
  }

  #lineById(id) {
    if (!this.hasListTarget) return null
    return Array.from(this.listTarget.children).find((line) => line.dataset.uploadId === String(id))
  }

  #key(file) {
    return [ file.name, file.size, file.lastModified ].join("|")
  }

  #megabytes(bytes) {
    return (bytes / 1024 / 1024).toLocaleString("es-ES", { maximumFractionDigits: 1 })
  }

  #message(key, values = {}) {
    const template = this.messagesValue[key] || ""
    const all = { max: Math.round(this.maxBytesValue / 1024 / 1024), ...values }
    return template.replace(/%\{(\w+)\}/g, (match, name) => (name in all ? all[name] : match))
  }

  #revokePreviews() {
    (this.previews || []).forEach((url) => URL.revokeObjectURL(url))
    this.previews = []
  }
}
