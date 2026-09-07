import { Controller } from "@hotwired/stimulus";

// Interactive tasting quiz (mirrors the React quiz). The server renders the
// taste parameters as JSON on the container; the search, selection, sliders
// and accuracy check all run client-side so no full-page reload is needed.
export default class extends Controller {
  static targets = [
    "query",
    "results",
    "searching",
    "searchEmpty",
    "selected",
    "sliders",
    "resultBlock",
    "resultValue",
    "resultDetail",
    "error",
  ];

  static values = {
    params: String, // JSON: [{slug,label,low,high,help}]
  };

  connect() {
    this.timer = null;
    this.tasteParams = JSON.parse(this.paramsValue);
    this.profile = null;
    this.profileParameters = {};
    this.testTaste = this.defaults();
    this.submitted = false;
    this.renderSliders();
  }

  defaults() {
    const values = {};
    this.tasteParams.forEach((p) => {
      values[p.slug] = 3;
    });
    return values;
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
      this.searchEmptyTarget.classList.add("hidden");
      return;
    }
    this.searchingTarget.hidden = false;
    this.searchEmptyTarget.classList.add("hidden");
    this.errorTarget.classList.add("hidden");
    try {
      const response = await fetch(`/quiz/search?q=${encodeURIComponent(trimmed)}`, {
        headers: { Accept: "application/json" },
      });
      const profiles = await response.json();
      this.renderResults(Array.isArray(profiles) ? profiles : []);
    } catch {
      this.errorTarget.classList.remove("hidden");
      this.resultsTarget.innerHTML = "";
    } finally {
      this.searchingTarget.hidden = true;
    }
  }

renderResults(profiles) {
    if (profiles.length === 0) {
      this.resultsTarget.innerHTML = "";
      this.searchEmptyTarget.classList.remove("hidden");
      return;
    }
    this.resultsTarget.innerHTML = profiles
      .map(
        (profile) =>
          `<button type="button" class="wine-search-result" data-action="quiz#select" data-profile="${this.escape(
            JSON.stringify(profile),
          )}"><strong>${this.escape(profile.name)}</strong></button>`,
      )
      .join("");
  }

  select(event) {
    const profile = JSON.parse(event.currentTarget.dataset.profile);
    this.profile = profile;
    this.profileParameters = profile.parameters || {};
    this.testTaste = this.defaults();
    this.submitted = false;
    this.renderSelected();
    this.renderSliders();
    this.resetResult();
    this.resultsTarget.innerHTML = "";
    this.queryTarget.value = "";
    this.searchEmptyTarget.classList.add("hidden");
  }

  renderSelected() {
    if (!this.profile) {
      this.selectedTarget.classList.add("hidden");
      return;
    }
    this.selectedTarget.classList.remove("hidden");
    const regions = Array.isArray(this.profile.regions)
      ? this.profile.regions.join(", ")
      : this.profile.regions || "";
    const notes = Array.isArray(this.profile.notes)
      ? this.profile.notes.join(", ")
      : this.profile.notes || "";
    this.selectedTarget.innerHTML = `
      <span>${this.escape(this.profile.color || "Wine")} · ${this.escape(regions)}</span>
      <h3>${this.escape(this.profile.name)}</h3>
      ${notes ? `<p>${this.escape(notes)}</p>` : ""}
      <button type="button" class="btn" data-action="quiz#clearSelection">Choose another wine</button>`;
  }

  clearSelection() {
    this.profile = null;
    this.profileParameters = {};
    this.selectedTarget.classList.add("hidden");
    this.selectedTarget.innerHTML = "";
    this.resetResult();
  }

  renderSliders() {
    this.slidersTarget.innerHTML = this.tasteParams
      .map(
        (param) => `
          <label class="wine-slider">
            <span class="wine-slider__top">
              <strong>${this.escape(param.label)}</strong>
              <output data-slug="${param.slug}">${this.testTaste[param.slug]}</output>
            </span>
            <input type="range" min="1" max="5" value="${this.testTaste[param.slug]}"
                   data-action="input->quiz#changeTaste" data-slug="${param.slug}">
            <span class="wine-slider__scale">
              <small>${this.escape(param.low)}</small>
              <small>${this.escape(param.high)}</small>
            </span>
            ${param.help ? `<em>${this.escape(param.help)}</em>` : ""}
          </label>`,
      )
      .join("");
    this.outputs = Array.from(this.slidersTarget.querySelectorAll("output[data-slug]"));
  }

  changeTaste(event) {
    const slug = event.currentTarget.dataset.slug;
    this.testTaste[slug] = Number(event.currentTarget.value);
    this.outputs
      .find((out) => out.dataset.slug === slug)
      .textContent = event.currentTarget.value;
    this.submitted = false;
    this.resetResult();
  }

  checkAccuracy() {
    if (!this.profile) return;
    this.submitted = true;
    this.resultBlockTarget.classList.remove("hidden");
    this.resultValueTarget.textContent = `${this.matchScore()}%`;
    this.renderResultDetail();
  }

  matchScore() {
    const totalDistance = this.tasteParams.reduce((total, param) => {
      return total + Math.abs((this.profileParameters[param.slug] ?? 3) - this.testTaste[param.slug]);
    }, 0);
    const maxDistance = this.tasteParams.length * 4;
    return Math.round((1 - totalDistance / maxDistance) * 100);
  }

  renderResultDetail() {
    const rows = this.tasteParams.map((param) => {
      return `<div><dt>${this.escape(param.label)}</dt><dd>You ${this.testTaste[param.slug]} / Target ${this.profileParameters[param.slug] ?? "—"}</dd></div>`;
    });
    this.resultDetailTarget.innerHTML = `<dl>${rows.join("")}</dl>`;
  }

  tryAgain() {
    this.testTaste = this.defaults();
    this.submitted = false;
    this.renderSliders();
    this.resetResult();
  }

  resetResult() {
    this.resultBlockTarget.classList.add("hidden");
    this.resultValueTarget.textContent = this.submitted ? `${this.matchScore()}%` : "--";
    this.resultDetailTarget.innerHTML = "";
  }

  escape(value) {
    const escapeMap = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return String(value || "").replace(/[&<>"']/g, (char) => escapeMap[char]);
  }
}
  }
}