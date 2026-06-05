export default function () {
  this.route("adminPlugins.show", { path: "/plugins" }, function () {
    this.route("discourse-quiz", { path: "/discourse-quiz" });
  });
}
