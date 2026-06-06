import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import QuizCategoryRow from "./quiz-category-row";

export default class QuizHome extends Component {
  @service quiz;

  @action
  startQuiz() {
    this.quiz.startQuiz();
  }

  @action
  resetSelection() {
    this.quiz.resetSelection();
  }

  <template>
    <div class="quiz-home">
      <div class="quiz-home-header">
        <h2 class="quiz-home-title">{{i18n "discourse_quiz.home_title"}}</h2>
        <p class="quiz-home-subtitle">{{i18n "discourse_quiz.home_subtitle"}}</p>
      </div>

      <div class="quiz-home-list">
        <div class="quiz-category-row">
          <span class="quiz-category-row__label">
            {{i18n "discourse_quiz.home_all_categories"}}
          </span>
          <DToggleSwitch
            @state={{this.quiz.selectAllMode}}
            {{on "click" this.quiz.toggleAllCategories}}
          />
        </div>

        {{#each this.quiz.availableCategories as |category|}}
          <QuizCategoryRow @category={{category}} />
        {{/each}}
      </div>

      {{#if this.quiz.quizStatus.is_guest}}
        <p class="quiz-status-hint">
          {{i18n
            "discourse_quiz.guest_attempts_left"
            count=this.quiz.quizStatus.attempts_left
          }}
        </p>
      {{/if}}

      {{#if this.quiz.isLearningOnly}}
        <p class="quiz-status-hint">{{i18n "discourse_quiz.learning_only"}}</p>
      {{/if}}

      <div class="quiz-home-footer">
        <p class="quiz-home-summary">{{this.quiz.selectedSummary}}</p>

        <DButton
          @label="discourse_quiz.home_reset"
          @action={{this.resetSelection}}
          class="btn-default quiz-home-reset-btn"
        />

        <DButton
          @label="discourse_quiz.home_start"
          @action={{this.startQuiz}}
          @disabled={{or this.quiz.loading (not this.quiz.canStart)}}
          class="btn-primary quiz-home-start-btn"
        />
      </div>
    </div>
  </template>
}
