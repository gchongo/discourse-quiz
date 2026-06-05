export default {
  resource: "admin.adminPlugins",
  map() {
    this.route("gamifiedQuiz", { path: "/gamified-quiz" });
  },
};
