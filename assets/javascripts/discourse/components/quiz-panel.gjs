import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { htmlSafe } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import QuizHome from "./quiz-home";
import QuizQuestionDisplay from "./quiz-question-display";
import QuizResultDisplay from "./quiz-result-display";
import QuizPaywall from "./quiz-paywall";

export default class QuizPanel extends Component {
  @service quiz;
  @service siteSettings;

  get panelStyles() {
    if (this.quiz.isMobile) {
      return "";
    }
    return htmlSafe("--quiz-panel-width: 300px;");
  }

  get containerClass() {
    const classes = ["quiz-panel-container"];
    if (this.quiz.isMobile) {
      classes.push("is-mobile");
    } else {
      classes.push(this.quiz.isDocked ? "is-docked" : "is-floating");
    }
    if (this.quiz.isMinimized) {
      classes.push("is-minimized");
    }
    if (this.quiz.panelVisible) {
      classes.push("is-visible");
    }
    return classes.join(" ");
  }

  <template>
    {{#if this.quiz.isEnabled}}
      <div class={{this.containerClass}} style={{this.panelStyles}}>
        <div class="quiz-panel-header">
          <div class="quiz-panel-title-row">
            {{#if this.quiz.isPlaying}}
              <DButton
                @icon="arrow-left"
                @action={{this.quiz.showHome}}
                @title="discourse_quiz.back_to_home"
                class="btn-default quiz-panel-control-btn quiz-panel-back-btn"
              />
            {{/if}}
            <span class="quiz-panel-title">{{i18n "gamified_quiz.panel_title"}}</span>
          </div>
          <div class="quiz-panel-controls">
            {{#if this.quiz.isMobile}}
              <DButton
                @icon={{if this.quiz.isMinimized "chevron-up" "chevron-down"}}
                @action={{this.quiz.toggleMinimize}}
                class="btn-default quiz-panel-control-btn"
              />
            {{else}}
              <DButton
                @icon={{if this.quiz.isDocked "up-right-from-square" "table-columns"}}
                @action={{this.quiz.toggleDock}}
                @title={{if this.quiz.isDocked "gamified_quiz.undock_panel" "gamified_quiz.dock_panel"}}
                class="btn-default quiz-panel-control-btn"
              />
            {{/if}}
            <DButton
              @icon="xmark"
              @action={{this.quiz.closePanel}}
              @title="gamified_quiz.close_panel"
              class="btn-default quiz-panel-control-btn quiz-panel-close-btn"
            />
          </div>
        </div>
        <div class="quiz-panel-content">
          {{#unless this.quiz.isMinimized}}
            {{#if this.quiz.loading}}
              <p class="quiz-panel-placeholder">{{i18n "discourse_quiz.loading"}}</p>
            {{else if this.quiz.paywallActive}}
              <QuizPaywall @status={{this.quiz.quizStatus}} />
            {{else if (eq this.quiz.panelPhase "home")}}
              {{#if this.quiz.errorMessage}}
                <p class="quiz-panel-error">{{this.quiz.errorMessage}}</p>
              {{else}}
                <QuizHome />
              {{/if}}
            {{else if this.quiz.errorMessage}}
              <p class="quiz-panel-error">{{this.quiz.errorMessage}}</p>
              <DButton
                @label="discourse_quiz.back_to_home"
                @action={{this.quiz.showHome}}
                class="btn-default"
              />
            {{else if this.quiz.currentQuestion}}
              {{#if this.quiz.answerResult}}
                <QuizResultDisplay
                  @question={{this.quiz.currentQuestion}}
                  @result={{this.quiz.answerResult}}
                />
              {{else}}
                <QuizQuestionDisplay @question={{this.quiz.currentQuestion}} />
              {{/if}}
            {{/if}}
          {{/unless}}
        </div>
      </div>
    {{/if}}
  </template>
}
