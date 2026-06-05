import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-quiz-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-quiz", "question-circle");
      api.addAdminPluginConfigurationNav("discourse-quiz", [
        {
          label: "gamified_quiz.admin_title",
          route: "adminPlugins.show.discourse-quiz",
        },
      ]);
    });
  },
};
