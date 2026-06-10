import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class QuizLeaderboardInfo extends Component {
  @service siteSettings;

  <template>
    <DModal
      @title={{i18n "discourse_quiz.leaderboard.modal.title"}}
      @closeModal={{@closeModal}}
      class="quiz-leaderboard-info-modal"
    >
      <:body>
        {{dIcon "award"}}
        <div class="quiz-leaderboard-info-modal__text">
          <p>{{i18n "discourse_quiz.leaderboard.modal.intro"}}</p>
          <p>{{i18n "discourse_quiz.leaderboard.modal.volume"}}</p>
          <p>
            {{i18n
              "discourse_quiz.leaderboard.modal.accuracy"
              count=this.siteSettings.quiz_leaderboard_min_attempts
            }}
          </p>
          <p>{{i18n "discourse_quiz.leaderboard.modal.profile"}}</p>
        </div>
      </:body>
    </DModal>
  </template>
}
