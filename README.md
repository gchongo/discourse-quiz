# discourse-quiz

Minimal Discourse plugin: quiz panel entry points and show/hide UI only.

## What is included

- **Desktop**: header icon toggles the quiz panel
- **Mobile**: sidebar link opens the quiz panel (`/quiz` route)
- **Panel**: dock/float (desktop), bottom drawer with minimize (mobile), close button

No backend API, database, admin UI, or scoring in this version.

## Installation

```yaml
# containers/app.yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - rm -rf discourse-quiz
          - git clone https://github.com/howhy-day/discourse-quiz.git
```

Then:

```bash
./launcher rebuild app
```

## Configuration

Enable **Admin → Settings → Plugins → quiz_plugin_enabled**.

## Testing

```bash
bin/qunit plugins/discourse-quiz/test/javascripts
```
