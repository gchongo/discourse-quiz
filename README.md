# discourse-quiz

A gamified quiz plugin for Discourse to increase community engagement by providing interactive quizzes with a scoring system.

## Features

- **Interactive Quiz Panel**: A docked/floating panel for desktop and a bottom drawer for mobile.
- **Scoring System**: Integrated with the Discourse Gamification plugin.
- **Guest Support**: Allow guests to try a limited number of questions before requiring registration.
- **Learning Mode**: Users can continue to answer questions for practice even after reaching their daily point limit.
- **Admin Management**: Full CRUD interface for managing questions and viewing statistics.
- **Automatic Auditing**: Weekly background jobs to check if source topics for questions are still accessible.

## Installation

1. Add the plugin URL to your `containers/app.yml`:
   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/gchongo/discourse-quiz.git
   ```
2. Rebuild your Discourse instance:
   ```bash
   ./launcher rebuild app
   ```

## Configuration

Settings are available in `Admin -> Settings -> Plugins -> discourse-quiz`:

- `quiz_plugin_enabled`: Main toggle to enable the plugin.
- `quiz_points_per_question`: Points awarded for each correct answer.
- `quiz_daily_max_points`: Daily point cap for users.
- `quiz_enable_guest_demo`: Whether to allow guests to try quizzes.
- `quiz_guest_attempt_limit`: Number of questions guests can attempt.
- `quiz_submit_cooldown_seconds`: Rate limiting between submissions.

## Admin Usage

Access the management interface at `/admin/plugins/discourse-quiz`. From here you can:
- Create, edit, and delete quiz questions.
- Enable or disable specific questions.
- View audit results for source topics.
- Monitor basic usage statistics.

## Development & Testing

### Running Ruby Tests
```bash
bin/rake autospec
# or
bin/rspec plugins/discourse-quiz
```

### Running JavaScript Tests
```bash
bin/rake qunit:test
```

## Known Limitations
- Categorization is currently text-based.
- Media support in questions depends on standard Discourse cooked output.
- Guest tracking is session-based.
