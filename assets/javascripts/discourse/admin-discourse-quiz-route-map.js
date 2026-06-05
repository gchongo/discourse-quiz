export default {
  resource: "admin.adminPlugins",
  map() {
    this.route("discourse-quiz", { path: "/discourse-quiz" });
  },
};
