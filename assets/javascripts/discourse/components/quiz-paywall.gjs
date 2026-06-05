import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";

export default class QuizPaywall extends Component {
  @action
  showLogin() {
    // Discourse standard way to trigger login modal
    const loginController = Discourse.__container__.lookup("controller:login");
    loginController.showLogin();
  }

  @action
  showCreateAccount() {
    const loginController = Discourse.__container__.lookup("controller:login");
    loginController.showCreateAccount();
  }

  <template>
    <div class="quiz-paywall">
      <div class="paywall-icon">
        {{dIcon "lock"}}
      </div>
      <p class="paywall-message">
        {{@status.paywall_message}}
      </p>
      <div class="paywall-actions">
        <dButton
          @icon="user"
          @action={{this.showLogin}}
          @label="gamified_quiz.login_to_continue"
          class="btn-primary"
        />
        <dButton
          @action={{this.showCreateAccount}}
          @label="gamified_quiz.signup_to_continue"
          class="btn-default"
        />
      </div>
    </div>
  </template>
}
