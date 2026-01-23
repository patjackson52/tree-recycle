# Deployment Guide - Tree Recycle App

This guide covers deploying the Tree Recycle application to Render.com, a free platform with PostgreSQL support and GitHub integration.

## Prerequisites

1. A GitHub account
2. The tree-recycle repository pushed to GitHub
3. Access to the following credentials:
   - Google Maps API Key
   - Stripe API keys
   - Twilio credentials
   - AWS credentials (for location services)
   - USPS API credentials
   - Rollbar access token
   - Rails master key

## Option 1: Deploy to Render.com (Recommended)

Render.com offers a free tier perfect for Rails applications with PostgreSQL databases.

### Step 1: Prepare Your Repository

All necessary configuration files have been created:
- ✅ `render.yaml` - Render service configuration
- ✅ `bin/render-build.sh` - Build script
- ✅ `Procfile` - Process definitions
- ✅ `config/database.yml` - Production database config

Commit and push these changes to your GitHub repository:

```bash
git add -A
git commit -m "Add Render.com deployment configuration"
git push origin claude/map-state-persistence-8MyVM
```

### Step 2: Get Your Rails Master Key

The Rails master key is required to decrypt credentials. Get it with:

```bash
cat config/master.key
```

**IMPORTANT:** Keep this key secure! Never commit it to git.

### Step 3: Create Render Account and Connect GitHub

1. Go to https://render.com
2. Sign up using your GitHub account
3. Authorize Render to access your repositories

### Step 4: Create New Web Service from Blueprint

1. Click "New +" button in Render dashboard
2. Select "Blueprint"
3. Connect your `tree-recycle` repository
4. Render will detect the `render.yaml` file
5. Click "Apply" to create all services

This will create:
- ✅ PostgreSQL database (tree-recycle-db)
- ✅ Web service (tree-recycle)
- ✅ Worker service (tree-recycle-worker) for background jobs

### Step 5: Configure Environment Variables

In the Render dashboard, go to your web service and add these environment variables:

#### Required Variables:

```
RAILS_MASTER_KEY=<your-master-key-from-step-2>
GOOGLE_MAPS_API_KEY=<your-google-maps-api-key>
STRIPE_PUBLISHABLE_KEY=<your-stripe-publishable-key>
STRIPE_SECRET_KEY=<your-stripe-secret-key>
TWILIO_ACCOUNT_SID=<your-twilio-account-sid>
TWILIO_AUTH_TOKEN=<your-twilio-auth-token>
TWILIO_PHONE_NUMBER=<your-twilio-phone-number>
AWS_REGION=<your-aws-region>
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
USPS_USER_ID=<your-usps-user-id>
ROLLBAR_ACCESS_TOKEN=<your-rollbar-token>
```

#### Auto-configured Variables (already set):
- `DATABASE_URL` - Automatically set from database
- `RAILS_ENV=production`
- `RAILS_SERVE_STATIC_FILES=true`

**Note:** Add these same environment variables to the worker service as well.

### Step 6: Deploy

1. After adding environment variables, Render will automatically deploy
2. The build process will:
   - Install dependencies
   - Precompile assets
   - Run database migrations
3. Monitor the deploy logs in the Render dashboard
4. Once complete, your app will be live at `https://tree-recycle.onrender.com` (or similar)

### Step 7: Custom Domain (Optional)

To use your existing domain (treerecycle.net):

1. In Render dashboard, go to your web service settings
2. Click "Custom Domains"
3. Add `treerecycle.net` and `www.treerecycle.net`
4. Follow Render's instructions to update your DNS records
5. Update `config/environments/production.rb` line 34 if needed

### Step 8: Enable Redis for Job Queue (Optional but Recommended)

For better background job performance:

1. In Render dashboard, click "New +" → "Redis"
2. Select free tier
3. Once created, copy the Internal Redis URL
4. Add `REDIS_URL` environment variable to both web and worker services
5. Redeploy

## Troubleshooting

### Build Failures

If the build fails:
1. Check the build logs in Render dashboard
2. Ensure all environment variables are set correctly
3. Verify `RAILS_MASTER_KEY` is correct

### Database Connection Issues

If you see database connection errors:
1. Verify the database service is running
2. Check that `DATABASE_URL` is properly linked
3. Ensure migrations ran successfully during build

### Asset Issues

If assets (CSS/JS) aren't loading:
1. Verify `RAILS_SERVE_STATIC_FILES=true` is set
2. Check that assets precompiled successfully in build logs
3. Verify `config.assets.compile = false` in `config/environments/production.rb`

### SSL/Force SSL Issues

The app is configured with `force_ssl = true`. Render provides SSL automatically, so this should work out of the box.

## Alternative Deployment Options

### Option 2: Railway.app

1. Go to https://railway.app
2. Sign in with GitHub
3. Click "New Project" → "Deploy from GitHub repo"
4. Select tree-recycle repository
5. Railway will auto-detect Rails and create PostgreSQL
6. Add environment variables in Railway dashboard
7. Deploy

### Option 3: Fly.io

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Initialize fly app
fly launch

# Set secrets
fly secrets set RAILS_MASTER_KEY=xxx
fly secrets set GOOGLE_MAPS_API_KEY=xxx
# ... etc

# Deploy
fly deploy
```

### Option 4: Heroku

```bash
# Install Heroku CLI
# https://devcenter.heroku.com/articles/heroku-cli

# Create app
heroku create tree-recycle

# Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# Set config vars
heroku config:set RAILS_MASTER_KEY=xxx
heroku config:set GOOGLE_MAPS_API_KEY=xxx
# ... etc

# Deploy
git push heroku main
```

## Post-Deployment Checklist

- [ ] App loads at public URL
- [ ] Database migrations completed
- [ ] Can sign in with existing credentials
- [ ] Map displays correctly with Google Maps
- [ ] Can create/edit reservations
- [ ] Background jobs are processing (check worker logs)
- [ ] SMS notifications work (Twilio)
- [ ] Payment processing works (Stripe)
- [ ] SSL certificate is active
- [ ] Custom domain configured (if applicable)

## Monitoring

- **Logs**: View logs in Render dashboard → Logs tab
- **Metrics**: Monitor service health in Render dashboard
- **Errors**: Check Rollbar for error tracking
- **Database**: Monitor database usage and connections

## Scaling

On Render's free tier:
- Web service sleeps after 15 minutes of inactivity
- First request after sleep may be slow (cold start)
- 750 hours/month of uptime

To upgrade:
1. Go to Render dashboard
2. Select your service
3. Choose a paid plan for always-on service

## Support

- Render Docs: https://render.com/docs
- Rails Deployment: https://guides.rubyonrails.org/getting_started.html
- Community: Render Community Forum

---

## Quick Reference

### Useful Commands for Local Testing

```bash
# Run production environment locally
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production rails server

# Check production logs
tail -f log/production.log

# Rails console in production
RAILS_ENV=production rails console
```

### Environment Variables Template

Save this template and fill in your values:

```bash
export RAILS_MASTER_KEY="your-master-key"
export GOOGLE_MAPS_API_KEY="your-google-maps-key"
export STRIPE_PUBLISHABLE_KEY="your-stripe-publishable-key"
export STRIPE_SECRET_KEY="your-stripe-secret-key"
export TWILIO_ACCOUNT_SID="your-twilio-sid"
export TWILIO_AUTH_TOKEN="your-twilio-token"
export TWILIO_PHONE_NUMBER="your-twilio-number"
export AWS_REGION="us-west-2"
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export USPS_USER_ID="your-usps-id"
export ROLLBAR_ACCESS_TOKEN="your-rollbar-token"
export DATABASE_URL="postgresql://user:pass@host/dbname"
```
