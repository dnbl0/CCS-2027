import { Controller } from "@hotwired/stimulus"

// "Print this page" on a record page (RecordAboutComponent): the browser's own print dialog
export default class extends Controller {
  print() { window.print() }
}
