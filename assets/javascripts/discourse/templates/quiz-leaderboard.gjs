import bodyClass from "discourse/helpers/body-class";
import QuizLeaderboardPage from "../components/quiz-leaderboard-page";

export default <template>
  {{bodyClass "quiz-leaderboard"}}

  <section class="container">
    <div class="contents clearfix body-page">
      <QuizLeaderboardPage />
    </div>
  </section>
</template>
