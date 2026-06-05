import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class QuizButton extends Component {
  @service quiz;

  <template>
    {{#if this.quiz.isEnabled}}
      <li class="header-dropdown-toggle quiz-header-icon">
        <DButton
          @action={{this.quiz.togglePanel}}
          tabindex="0"
          class={{dConcatClass "icon" "btn-flat" (if this.quiz.panelVisible "active")}}
          title={{i18n "gamified_quiz.button_title"}}
        >
          {{~dIcon "question-circle"~}}
        </DButton>
      </li>
    {{/if}}
  </template>
}
