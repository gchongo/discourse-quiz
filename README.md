# discourse-quiz

A gamified quiz plugin for Discourse to increase community engagement by providing interactive quizzes with a scoring system.

## Features

- **Interactive quiz panel**: A docked/floating panel for desktop and a bottom drawer for mobile.
- **Scoring system**: Integrated with the Discourse Gamification plugin.
- **Guest support**: Allow guests to try a limited number of questions before requiring registration.
- **Learning mode**: Users can continue to answer questions for practice even after reaching their daily point limit.
- **Admin management**: Full CRUD interface for managing questions and viewing statistics.
- **Automatic auditing**: Weekly background jobs to check if source topics for questions are still accessible.

## Installation

1. Add the plugin URL to your `containers/app.yml`:
   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/howhy-day/discourse-quiz.git
   ```
2. Rebuild your Discourse instance:
   ```bash
   ./launcher rebuild app
   ```

## Configuration

Settings are available in **Admin → Settings → Plugins → discourse-quiz**:

- `quiz_plugin_enabled`: Main toggle to enable the plugin.
- `quiz_categories`: Comma-separated category IDs used to filter quiz questions.
- `quiz_points_per_question`: Points awarded for each correct answer.
- `quiz_daily_max_points`: Daily point cap for users.
- `quiz_enable_guest_demo`: Whether to allow guests to try quizzes.
- `quiz_guest_attempt_limit`: Number of questions guests can attempt.
- `quiz_submit_cooldown_seconds`: Rate limiting between submissions.

## Admin usage

Access the management interface at `/admin/plugins/discourse-quiz`. From here you can:

- Create, edit, and delete quiz questions.
- Enable or disable specific questions.
- View audit results for source topics.
- Monitor basic usage statistics.

## Development and testing

### Running Ruby tests

```bash
bin/rspec plugins/discourse-quiz
```

### Running JavaScript tests

```bash
bin/qunit plugins/discourse-quiz/test/javascripts
```

## Known limitations

- Categorization is currently text-based and matched against Discourse category names when `quiz_categories` is set.
- Media support in questions depends on plain text rendering.
- Guest tracking is session-based.
