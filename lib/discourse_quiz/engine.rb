# frozen_string_literal: true

module ::DiscourseQuiz
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseQuiz

    config.to_prepare do
      Rails.autoloaders.main.eager_load_namespace(DiscourseQuiz) if Rails.env.production?
    end
  end
end
