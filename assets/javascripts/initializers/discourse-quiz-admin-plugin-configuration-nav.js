import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-quiz-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-quiz", "circle-question");
      api.addAdminPluginConfigurationNav("discourse-quiz", [
        {
          label: "discourse_quiz.admin.title",
          route: "adminPlugins.show.discourse-quiz",
        },
        {
          label: "discourse_quiz.admin.rewards_title",
          route: "adminPlugins.show.discourse-quiz-rewards",
        },
      ]);
    });
  },
};
