import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import dButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import dIcon from "discourse-common/helpers/d-icon";

export default class QuizButton extends Component {
  @service quiz;

  <template>
    {{#if this.quiz.isEnabled}}
      <dButton
        @icon="question-circle"
        @action={{this.quiz.togglePanel}}
        @title="gamified_quiz.button_title"
        class="quiz-button btn-flat"
      />
    {{/if}}
  </template>
}
