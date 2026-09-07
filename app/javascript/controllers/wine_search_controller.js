import { Controller } from "@hotwired/stimulus";

// Global wine search-as-you-type (mirrors React's /search). Debounces input
// and swaps in JSON results without a full-page reload.
export default class extends Controller {
  static targets = ["query", "results", "searching", "empty", "error"];

  connect() {
    this.timer = null;
  }

  search({ params: { value } }) {
    if (this.timer) window.clearTimeout(this.timer);
    this.timer = window.setTimeout(() => this.performSearch(value), 300);
  }

  searchEnter(event) {
    if (event.key === "Enter") {
      if (this.timer) window.clearTimeout(this.timer);
      this.performSearch(this.queryTarget.value);
    }
  }

  async performSearch(query) {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      this.resultsTarget.innerHTML = "";
      this.emptyTarget.classList.add("hidden");
      return;
    }
    this.searchingTarget.hidden = false;
    this.emptyTarget.classList.add("hidden");
    this.errorTarget.classList.add("hidden");
    try {
      const response = await fetch(`/search/results?query=${encodeURIComponent(trimmed)}`, {
        headers: { Accept: "application/json" },
      });
      const wines = await response.json();
      this.renderResults(Array.isArray(wines) ? wines : []);
    } catch {
      this.errorTarget.classList.remove("hidden");
      this.resultsTarget.innerHTML = "";
    } finally {
      this.searchingTarget.hidden = true;
    }
  }

  renderResults(wines) {
    if (wines.length === 0) {
      this.resultsTarget.innerHTML = "";
      this.emptyTarget.classList.remove("hidden");
      return;
    }
    const href = (slug) => `/wines/${encodeURIComponent(slug)}`;
    this.resultsTarget.innerHTML = wines.map((wine) => {
      const meta = [
        wine.producer,
        wine.color,
        wine.regions.length ? wine.regions.join(", ") : null,
        wine.vintage_years.length ? wine.vintage_years.join(", ") : null,
      ].filter(Boolean).join(" · ");
      return `<a href="${href(wine.slug)}" class="wine-search-result">
        <strong>${this.escape(wine.name)}</strong>
        ${meta ? `<span>${this.escape(meta)}</span>` : ""}
        ${wine.score ? `<span class="score">Score ${wine.score}</span>` : ""}
      </a>`;
    }).join("");
  }

  escape(value) {
    const map = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
    return String(value || "").replace(/[&<>"']/g, (c) => map[c]);
  }
}