# discourse-quiz

A gamified quiz plugin for Discourse to increase community engagement by providing interactive quizzes with a scoring system.

Compatible with Discourse v2026.6.x and later.

## Features

- **Interactive quiz panel**: A docked/floating panel for desktop and a bottom drawer for mobile.
- **Scoring system**: Integrated with the Discourse Gamification plugin (optional).
- **Guest support**: Allow guests to try a limited number of questions before requiring registration.
- **Learning mode**: Users can continue to answer questions for practice even after reaching their daily point limit.
- **Admin management**: Full CRUD interface for managing questions and viewing statistics.
- **Automatic auditing**: Weekly background jobs to check if source topics for questions are still accessible.

## Installation (standalone repository)

Add the plugin to your `containers/app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - rm -rf discourse-quiz
          - git clone https://github.com/howhy-day/discourse-quiz.git
          - cd discourse-quiz && git checkout v1.0.0
```

Rebuild your Discourse instance (required for Ruby, database, and JavaScript changes):

```bash
./launcher rebuild app
```

Do not use `./launcher start app` alone after installing or updating this plugin.

## Configuration

Settings are available in **Admin → Settings → Plugins → discourse-quiz**:

- `quiz_plugin_enabled`: Main toggle to enable the plugin.
- `quiz_categories`: Comma-separated category IDs used to filter quiz questions.
- `quiz_points_per_question`: Points awarded for each correct answer (requires discourse-gamification).
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

### Linting

```bash
bin/lint plugins/discourse-quiz
```

## Deployment checklist

1. Enable `quiz_plugin_enabled` in admin settings.
2. Confirm header quiz icon and sidebar link appear on the frontend.
3. Confirm `/admin/plugins/discourse-quiz` loads and CRUD works without 500 errors.
4. Confirm default questions exist (`SELECT COUNT(*) FROM discourse_quiz_questions`).

## Troubleshooting rebuild failures

If `./launcher rebuild app` fails during `db:migrate`:

```bash
./launcher enter app
cd /var/www/discourse
RAILS_ENV=production bundle exec rake db:migrate
```

If a migration version is stuck, remove only the failed version from `schema_migrations` after fixing the underlying issue.

## Release tags

| Tag | Description |
|-----|-------------|
| `v1.0.0` | Framework rebuild: MVP + gamification + audit |

## Known limitations

- Categorization is text-based and matched against Discourse category names when `quiz_categories` is set.
- Media support in questions depends on plain text rendering.
- Guest tracking is session-based.
