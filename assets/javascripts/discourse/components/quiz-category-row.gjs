import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

export default class QuizCategoryRow extends Component {
  @service quiz;

  get isOn() {
    return this.quiz.isCategorySelected(this.args.category);
  }

  @action
  toggle() {
    this.quiz.toggleCategory(this.args.category);
  }

  <template>
    <div class="quiz-category-row">
      <span class="quiz-category-row__label">{{@category}}</span>
      <DToggleSwitch @state={{this.isOn}} {{on "click" this.toggle}} />
    </div>
  </template>
}
