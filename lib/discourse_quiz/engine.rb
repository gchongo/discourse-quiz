# frozen_string_literal: true

module ::DiscourseQuiz
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseQuiz

    config.to_prepare do
      Dir[
        File.expand_path(File.join("..", "..", "app", "jobs", "**", "*.rb"), __dir__)
      ].each { |job| require_dependency job }
    end
  end
end
