import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { waitForPromise } from "@ember/test-waiters";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cook } from "discourse/lib/text";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";

export default class QuizCookedText extends Component {
  @tracked cooked = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadCookedText();
  }

  @action
  async loadCookedText() {
    const rawText = this.args.rawText || "";
    const cooked = await waitForPromise(cook(rawText));

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.args.rawText !== rawText) {
      return;
    }

    this.cooked = cooked;
  }

  <template>
    <div ...attributes {{didUpdate this.loadCookedText @rawText}}>
      {{#if this.cooked}}
        <DDecoratedHtml @html={{this.cooked}} />
      {{/if}}
    </div>
  </template>
}
