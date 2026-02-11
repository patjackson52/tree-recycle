# Deploying tree-recycle to Heroku (Container registry) — notes

This document explains the steps to deploy the app to Heroku using the GitHub Actions workflow in
`.github/workflows/deploy-heroku.yml`. The workflow builds the image, pushes it to Heroku's
container registry and runs a release that executes the `release` process from the Procfile
(which runs `rails db:migrate`).

1) Create a Heroku app (one-time)
   - Install the Heroku CLI locally:
     https://devcenter.heroku.com/articles/heroku-cli
   - Create an app:
     heroku create <your-app-name>
   - Or use an existing app name if you've already created one via the Heroku dashboard.

2) Add Postgres and Redis addons
   - Add Heroku Postgres:
     heroku addons:create heroku-postgresql:mini --app <your-app-name>
   - Add Heroku Data for Redis:
     heroku addons:create heroku-redis:mini --app <your-app-name>
   - Note: Use the plan tier that fits your needs (mini, basic, etc.)

3) Enable PostGIS extension on Postgres
   - Connect to your Heroku Postgres database:
     heroku pg:psql --app <your-app-name>
   - Run the following command in the psql console:
     CREATE EXTENSION IF NOT EXISTS postgis;
   - Exit with \q

4) Set required config vars on Heroku
   - Set the Rails master key (for decrypting credentials.yml.enc):
     heroku config:set RAILS_MASTER_KEY=<your-master-key> --app <your-app-name>
   - Set the Rails environment:
     heroku config:set RAILS_ENV=production --app <your-app-name>
   - Set the Rails serve static files (if needed):
     heroku config:set RAILS_SERVE_STATIC_FILES=true --app <your-app-name>
   - Set any other environment variables your app needs (see config/credentials.yml.enc)

5) Configure GitHub repository secrets for the workflow
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     * HEROKU_APP_NAME: <your-app-name>
     * HEROKU_API_KEY: <your-heroku-api-key>
       (Get this from: heroku auth:token or from Heroku dashboard → Account Settings → API Key)
     * HEROKU_EMAIL: <your-heroku-email>

6) Deploy via GitHub Actions
   - Push to main or master branch, or manually trigger the workflow from the Actions tab
   - The workflow will:
     a. Build the Docker image
     b. Push to Heroku Container Registry
     c. Release the image (which runs the release phase with db:migrate)

7) Enable the worker dyno (for background jobs)
   - After first deployment:
     heroku ps:scale worker=1 --app <your-app-name>
   - This is needed for sending emails and other background jobs via delayed_job

8) Notes on ActiveStorage
   - If using ActiveStorage for file uploads, configure your storage service
   - For production, consider using Amazon S3, Google Cloud Storage, or similar
   - Update config/storage.yml and set ACTIVE_STORAGE_SERVICE config var if needed

9) Notes on SMTP/Email configuration
   - Email settings are configured in config/environments/production.rb
   - SMTP credentials should be in config/credentials.yml.enc
   - For Gmail: enable "Less secure app access" or use App Passwords
   - See main README.md for detailed email configuration

10) Worker scaling
    - By default, worker dyno is scaled to 0 (off)
    - Scale worker to 1 to enable background job processing:
      heroku ps:scale worker=1 --app <your-app-name>
    - Monitor worker with:
      heroku ps --app <your-app-name>
    - View worker logs:
      heroku logs --ps worker --app <your-app-name>

## Manual migration (if needed)

If you need to run migrations manually:

```bash
heroku run rails db:migrate --app <your-app-name>
```

## Troubleshooting

### Check logs
```bash
heroku logs --tail --app <your-app-name>
```

### Check dyno status
```bash
heroku ps --app <your-app-name>
```

### Restart dynos
```bash
heroku restart --app <your-app-name>
```

### Run Rails console
```bash
heroku run rails console --app <your-app-name>
```

### Check database
```bash
heroku pg:info --app <your-app-name>
```

### Check Redis
```bash
heroku redis:info --app <your-app-name>
```

### View config vars
```bash
heroku config --app <your-app-name>
```

### Reset database (destructive!)
```bash
heroku pg:reset DATABASE --app <your-app-name>
heroku run rails db:migrate --app <your-app-name>
heroku run rails db:seed --app <your-app-name>
```

## Container Registry specific commands

### Build and push manually (if not using GitHub Actions)
```bash
heroku container:login
docker build -t registry.heroku.com/<your-app-name>/web .
docker push registry.heroku.com/<your-app-name>/web
heroku container:release web --app <your-app-name>
```

### View container logs
```bash
heroku logs --tail --ps web --app <your-app-name>
```
