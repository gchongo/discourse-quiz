import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class QuizPaywall extends Component {
  get message() {
    return (
      this.args.status?.paywall_message || i18n("discourse_quiz.paywall_default")
    );
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  showCreateAccount() {
    getOwner(this).lookup("route:application").send("showCreateAccount");
  }

  <template>
    <div class="quiz-paywall">
      <div class="quiz-paywall-icon">
        {{dIcon "lock"}}
      </div>
      <p class="quiz-paywall-message">{{this.message}}</p>
      <div class="quiz-paywall-actions">
        <DButton
          @icon="user"
          @label="discourse_quiz.login_to_continue"
          @action={{this.showLogin}}
          class="btn-primary"
        />
        <DButton
          @label="discourse_quiz.signup_to_continue"
          @action={{this.showCreateAccount}}
          class="btn-default"
        />
      </div>
    </div>
  </template>
}
