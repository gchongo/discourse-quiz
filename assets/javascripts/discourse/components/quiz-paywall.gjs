import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";

export default class QuizPaywall extends Component {
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
