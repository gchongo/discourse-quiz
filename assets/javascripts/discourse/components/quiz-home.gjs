import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";

export default class QuizHome extends Component {
  @service quiz;

  get selectedCategory() {
    return this.quiz.selectedCategory;
  }

  @action
  selectCategory(category) {
    this.quiz.selectCategory(category);
  }

  @action
  startQuiz() {
    this.quiz.startQuiz();
  }

  <template>
    <div class="quiz-home">
      <p class="quiz-home-intro">{{i18n "discourse_quiz.home_intro"}}</p>

      <div class="quiz-home-section">
        <div class="quiz-home-label">{{i18n "discourse_quiz.home_range_label"}}</div>
        <ul class="quiz-category-list">
          <li>
            <button
              type="button"
              class="quiz-category-btn {{if (eq this.selectedCategory '') 'is-selected'}}"
              {{on "click" (fn this.selectCategory "")}}
            >
              {{i18n "discourse_quiz.home_all_categories"}}
            </button>
          </li>
          {{#each this.quiz.availableCategories as |category|}}
            <li>
              <button
                type="button"
                class="quiz-category-btn {{if (eq this.selectedCategory category) 'is-selected'}}"
                {{on "click" (fn this.selectCategory category)}}
              >
                {{category}}
              </button>
            </li>
          {{/each}}
        </ul>
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

      <DButton
        @label="discourse_quiz.home_start"
        @action={{this.startQuiz}}
        @disabled={{this.quiz.loading}}
        class="btn-primary quiz-home-start-btn"
      />
    </div>
  </template>
}
