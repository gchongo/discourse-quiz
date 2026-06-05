import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import cooked from "discourse/helpers/cooked";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";
import { on } from "@ember/modifier";

export default class QuizResultDisplay extends Component {
  @service siteSettings;

  get isCorrect() {
    return this.args.result.correct;
  }

  get showSource() {
    return this.siteSettings.quiz_show_source_link && this.args.question.source_topic_id;
  }

  <template>
    <div class="quiz-result-display {{if this.isCorrect 'is-correct' 'is-incorrect'}}">
      <div class="result-header">
        <span class="result-icon">
          {{#if this.isCorrect}}
            {{dIcon "check-circle"}}
          {{else}}
            {{dIcon "times-circle"}}
          {{/if}}
        </span>
        <span class="result-text">
          {{#if this.isCorrect}}
            {{i18n "gamified_quiz.correct"}}
          {{else}}
            {{i18n "gamified_quiz.incorrect"}}
          {{/if}}
        </span>
      </div>

      {{#if this.args.result.explanation}}
        <div class="result-explanation">
          {{cooked this.args.result.explanation}}
        </div>
      {{/if}}

      <div class="result-actions">
        {{#if this.showSource}}
          <a href="/t/{{@question.source_topic_id}}" class="btn btn-default quiz-source-link" target="_blank" rel="noopener noreferrer">
            {{dIcon "external-link-alt"}}
            {{i18n "gamified_quiz.source_link"}}
          </a>
        {{/if}}

        <button class="btn btn-primary quiz-next-btn" type="button" {{on "click" @onNext}}>
          {{i18n "gamified_quiz.next"}}
        </button>
      </div>
    </div>
  </template>
}
