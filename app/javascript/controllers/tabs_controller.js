import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["active"]
  static targets = ["btn", "tab"]
  static values = { defaultTab: { type: String, default: "hn" } }

  connect() {
    this.showTab(this.defaultTabValue)
  }

  select(event) {
    const tabId = event.currentTarget.dataset.tabId
    this.showTab(tabId)
  }

  showTab(tabId) {
    this.tabTargets.forEach(t => t.hidden = (t.dataset.tabId !== tabId))
    this.btnTargets.forEach(b => {
      if (b.dataset.tabId === tabId) {
        b.classList.add(...this.activeClasses)
      } else {
        b.classList.remove(...this.activeClasses)
      }
    })
  }
}
