import { Controller } from "@hotwired/stimulus";

// Keeps the finder's slider <output> in sync as the user drags.
export default class extends Controller {
  updateOutput(event) {
    const outputId = event.currentTarget.dataset.output;
    const output = document.getElementById(outputId);
    if (output) output.textContent = event.currentTarget.value;
  }
}