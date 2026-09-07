import { Controller } from "@hotwired/stimulus";

// Hover/click dropdown for the header nav menus (mirrors the React header).
// Keeps one menu open, closes when clicking outside, and opens on mouseenter.
export default class extends Controller {
  static targets = ["menu", "summary"];

  connect() {
    this.closeTimer = null;
    this.element.addEventListener("mouseenter", () => this.open());
    this.element.addEventListener("mouseleave", () => this.scheduleClose());
  }

  toggle(event) {
    event.preventDefault();
    this.element.open ? this.close() : this.open();
  }

  open() {
    if (this.closeTimer) window.clearTimeout(this.closeTimer);
    this.closeTimer = null;
    this.element.setAttribute("open", "");
  }

  scheduleClose() {
    if (this.closeTimer) window.clearTimeout(this.closeTimer);
    this.closeTimer = window.setTimeout(() => this.close(), 250);
  }

  close() {
    this.element.removeAttribute("open");
  }
}