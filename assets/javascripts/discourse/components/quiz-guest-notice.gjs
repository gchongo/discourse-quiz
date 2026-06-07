import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class QuizGuestNotice extends Component {
  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  @action
  showCreateAccount() {
    getOwner(this).lookup("route:application").send("showCreateAccount");
  }

  <template>
    <div class="quiz-guest-notice">
      <div class="quiz-guest-notice__icon">
        {{dIcon "user"}}
      </div>
      <div class="quiz-guest-notice__message">
        <span class="quiz-guest-notice__line">
          {{i18n "discourse_quiz.guest_home_notice_modes"}}
        </span>
        <span class="quiz-guest-notice__line">
          {{i18n
            "discourse_quiz.guest_home_notice_tries"
            count=@attemptsLeft
          }}
        </span>
      </div>
      <div class="quiz-guest-notice__actions">
        <DButton
          @label="discourse_quiz.login_to_continue"
          @action={{this.showLogin}}
          class="btn-primary btn-small quiz-guest-notice__btn"
        />
        <DButton
          @label="discourse_quiz.signup_to_continue"
          @action={{this.showCreateAccount}}
          class="btn-default btn-small quiz-guest-notice__btn"
        />
      </div>
    </div>
  </template>
}
