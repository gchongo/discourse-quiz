import { withPluginApi } from "discourse/lib/plugin-api";
import QuizButton from "../components/quiz-button";

export default {
  name: "discourse-quiz",

  initialize() {
    withPluginApi((api) => {
      api.headerIcons.add("discourse-quiz", QuizButton, {
        before: "search",
      });
    });
  },
};
