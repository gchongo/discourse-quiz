import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import dButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { htmlSafe } from "@ember/template";
import dIcon from "discourse-common/helpers/d-icon";
import { on } from "@ember/modifier";
import { or } from "discourse/truth-helpers";
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
    const width = this.siteSettings.quiz_desktop_sidebar_width || "300px";
    return htmlSafe(`--quiz-panel-width: ${width};`);
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

  get isLearningMode() {
    return this.quiz.status?.mode === "learning_only";
  }

  get isPaywallMode() {
    return this.quiz.status?.mode === "paywall";
  }

  get isReadyState() {
    return this.quiz.state === "ready";
  }

  get isSubmittingState() {
    return this.quiz.state === "submitting";
  }

  get isResultState() {
    return this.quiz.state === "result";
  }

  get isErrorState() {
    return this.quiz.state === "error";
  }

  get isLoadingState() {
    return this.quiz.state === "loading";
  }

  <template>
    {{#if this.quiz.isEnabled}}
      <div class={{this.containerClass}} style={{this.panelStyles}}>
        <div class="quiz-panel-header">
          <span class="quiz-panel-title">
            {{i18n "gamified_quiz.panel_title"}}
            {{#if this.isLearningMode}}
              <span class="learning-mode-badge" title={{i18n "gamified_quiz.learning_mode"}}>
                {{dIcon "graduation-cap"}}
              </span>
            {{/if}}
          </span>
          <div class="quiz-panel-controls">
            {{#if this.quiz.isMobile}}
              <dButton
                @icon={{if this.quiz.isMinimized "chevron-up" "chevron-down"}}
                @action={{this.quiz.toggleMinimize}}
                class="btn-flat"
              />
            {{else}}
              <dButton
                @icon={{if this.quiz.isDocked "external-link-alt" "columns"}}
                @action={{this.quiz.toggleDock}}
                @title={{if this.quiz.isDocked "gamified_quiz.undock_panel" "gamified_quiz.dock_panel"}}
                class="btn-flat"
              />
            {{/if}}
            <dButton
              @icon="times"
              @action={{this.quiz.closePanel}}
              @title="gamified_quiz.close_panel"
              class="btn-flat"
            />
          </div>
        </div>
        <div class="quiz-panel-content">
          {{#unless this.quiz.isMinimized}}
            {{#if this.isPaywallMode}}
              <QuizPaywall @status={{this.quiz.status}} />
            {{else if this.isLoadingState}}
              <div class="quiz-loading">
                <div class="spinner"></div>
                <p>{{i18n "gamified_quiz.loading"}}</p>
              </div>
            {{else if this.isReadyState}}
              <QuizQuestionDisplay
                @question={{this.quiz.currentQuestion}}
                @onSubmit={{this.quiz.submitAnswer}}
              />
            {{else if this.isSubmittingState}}
              <QuizQuestionDisplay
                @question={{this.quiz.currentQuestion}}
                @disabled={{true}}
              />
            {{else if this.isResultState}}
              <QuizResultDisplay
                @question={{this.quiz.currentQuestion}}
                @result={{this.quiz.lastResult}}
                @onNext={{this.quiz.nextQuestion}}
              />
            {{else if this.isErrorState}}
              <div class="quiz-error">
                {{dIcon "exclamation-triangle"}}
                <p>{{(or this.quiz.errorMessage (i18n "gamified_quiz.error"))}}</p>
                <button class="btn btn-default" {{on "click" this.quiz.loadInitialData}}>
                  {{dIcon "sync"}}
                  {{i18n "gamified_quiz.next"}}
                </button>
              </div>
            {{/if}}
          {{/unless}}
        </div>
      </div>
    {{/if}}
  </template>
}
