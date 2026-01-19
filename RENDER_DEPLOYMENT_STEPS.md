# Render.com Deployment - Step by Step Guide

This guide will walk you through deploying the tree-recycle app to Render.com.

## Prerequisites Check ✅

- ✅ Render.yaml configuration file created
- ✅ Build script (bin/render-build.sh) created
- ✅ Procfile updated with web process
- ✅ Production database configuration added
- ✅ Code pushed to GitHub branch: `claude/map-state-persistence-8MyVM`

## Important: Rails Credentials

This app uses Rails encrypted credentials to store sensitive information like:
- Google Maps API key
- Stripe keys (publishable and secret)
- Twilio credentials (SID, auth token, phone number)
- USPS username
- Email credentials

**You'll need the Rails master key to decrypt these credentials in production.**

### Option A: If you have the existing master.key file

If you have the original `config/master.key` file from development:
- Keep it safe - you'll need to add it to Render as `RAILS_MASTER_KEY`

### Option B: If you need to create new credentials

If you don't have the master key, you'll need to create new credentials:

```bash
# 1. Remove old encrypted credentials (back it up first!)
mv config/credentials.yml.enc config/credentials.yml.enc.backup

# 2. Create new credentials file
EDITOR=vim rails credentials:edit

# 3. Add your credentials using the template from config/credentials_sample.yml
# Copy and paste the structure, then fill in your actual values

# 4. Save and exit (ESC + :wq in vim)
# This will create a new config/master.key file

# 5. Get your new master key
cat config/master.key
```

---

## Step-by-Step Deployment to Render.com

### Step 1: Merge Your Branch (Recommended)

First, let's merge your feature branch to main:

```bash
# Checkout main branch
git checkout main

# Pull latest changes
git pull origin main

# Merge your feature branch
git merge claude/map-state-persistence-8MyVM

# Push to main
git push origin main
```

**OR** you can deploy directly from the feature branch (Render will ask which branch to use).

### Step 2: Create Render.com Account

1. Go to https://render.com
2. Click "Get Started for Free"
3. Click "GitHub" to sign up with your GitHub account
4. Authorize Render to access your GitHub repositories

### Step 3: Deploy from Blueprint

1. In Render dashboard, click the **"New +"** button (top right)
2. Select **"Blueprint"**
3. You'll see a list of your GitHub repositories
4. Find and select **`tree-recycle`** (or `patjackson52/tree-recycle`)
5. Render will detect the `render.yaml` file
6. Click **"Apply"** button

Render will now create:
- ✅ PostgreSQL database service (`tree-recycle-db`)
- ✅ Web service (`tree-recycle`)
- ✅ Worker service (`tree-recycle-worker`)

**Note:** All services will start with "Pending" or "Deploy failed" status until you add environment variables.

### Step 4: Configure Environment Variables for Web Service

1. In Render dashboard, click on your **`tree-recycle`** web service
2. Go to **"Environment"** tab in the left sidebar
3. Scroll down to **"Environment Variables"** section
4. Click **"Add Environment Variable"** for each of the following:

#### Required Variables:

| Key | Value | Notes |
|-----|-------|-------|
| `RAILS_MASTER_KEY` | `[your-master-key]` | From config/master.key or newly generated |
| `RAILS_ENV` | `production` | Already set by render.yaml |
| `RAILS_SERVE_STATIC_FILES` | `true` | Already set by render.yaml |
| `DATABASE_URL` | (auto-set) | Automatically linked from database |

#### Credentials Variables (if not using encrypted credentials):

If you prefer to use environment variables instead of Rails encrypted credentials, add these:

| Key | Value |
|-----|-------|
| `GOOGLE_MAPS_API_KEY` | Your Google Maps API key |
| `STRIPE_PUBLISHABLE_KEY` | Your Stripe publishable key |
| `STRIPE_SECRET_KEY` | Your Stripe secret key |
| `TWILIO_ACCOUNT_SID` | Your Twilio account SID |
| `TWILIO_AUTH_TOKEN` | Your Twilio auth token |
| `TWILIO_PHONE_NUMBER` | Your Twilio phone number (e.g., +1234567890) |
| `USPS_USER_ID` | Your USPS API username |
| `ROLLBAR_ACCESS_TOKEN` | Your Rollbar token (optional) |

**Note:** If you're using Rails encrypted credentials properly with RAILS_MASTER_KEY, you don't need these individual variables.

### Step 5: Configure Environment Variables for Worker Service

1. Click on your **`tree-recycle-worker`** service
2. Go to **"Environment"** tab
3. Add the same environment variables as the web service (except `RAILS_SERVE_STATIC_FILES`)

### Step 6: Trigger Deployment

Once you've added `RAILS_MASTER_KEY`:

1. Go back to your **`tree-recycle`** web service
2. Click **"Manual Deploy"** button (top right)
3. Select **"Deploy latest commit"**
4. Click **"Deploy"**

### Step 7: Monitor Deployment

1. Click on **"Logs"** tab to watch the deployment
2. You'll see:
   - Bundle install
   - Asset precompilation
   - Database migrations
   - Server starting

**Build process should complete in 5-10 minutes.**

### Step 8: Check Database Migrations

The database should be automatically created and migrated during deployment. If you see migration errors:

1. Go to your database service (`tree-recycle-db`)
2. Click **"Connect"** to get connection info
3. You can run migrations manually through the shell if needed

### Step 9: Access Your Deployed App

1. Go to your web service dashboard
2. At the top, you'll see your app URL (e.g., `https://tree-recycle.onrender.com`)
3. Click it to open your app

**🎉 Your app should now be live!**

---

## Post-Deployment Tasks

### Verify Everything Works

- [ ] App loads without errors
- [ ] Can view the home page
- [ ] Can sign in (create an admin user if needed)
- [ ] Map displays correctly
- [ ] Can create/view reservations
- [ ] Background jobs are running (check worker logs)

### Create Admin User

If you need to create an admin user in production:

1. Go to your web service
2. Click **"Shell"** tab (access Rails console)
3. Run:
```ruby
User.create!(
  email: 'admin@example.com',
  password: 'secure_password',
  role: 'admin',
  first_name: 'Admin',
  last_name: 'User'
)
```

### Set Up Custom Domain (Optional)

To use `treerecycle.net`:

1. In your web service, go to **"Settings"** tab
2. Scroll to **"Custom Domains"**
3. Click **"Add Custom Domain"**
4. Enter `treerecycle.net`
5. Add another: `www.treerecycle.net`
6. Render will provide DNS instructions
7. Update your domain's DNS records with your domain registrar

---

## Troubleshooting

### Build Failed - Missing Dependencies

**Error:** "Bundle install failed"

**Solution:** Check Gemfile.lock is committed to git:
```bash
git add Gemfile.lock
git commit -m "Add Gemfile.lock"
git push
```

### Build Failed - Master Key Invalid

**Error:** "Rails master key is invalid"

**Solution:**
1. Double-check your RAILS_MASTER_KEY is correct
2. Make sure there are no extra spaces or newlines
3. Generate new credentials if needed (see Option B above)

### Database Connection Error

**Error:** "Could not connect to database"

**Solution:**
1. Verify DATABASE_URL is set (should be automatic)
2. Check database service is running
3. Try manual migration through shell

### Assets Not Loading (404 errors)

**Error:** CSS/JS files return 404

**Solution:**
1. Verify `RAILS_SERVE_STATIC_FILES=true` is set
2. Check asset precompilation succeeded in build logs
3. Try manual deploy with cleared cache

### App Sleeps After 15 Minutes (Free Tier)

**Issue:** First request after inactivity is slow

**Solution:** This is expected on Render's free tier. Upgrade to paid plan for always-on service.

### Background Jobs Not Running

**Issue:** Delayed jobs not processing

**Solution:**
1. Check worker service is running
2. Verify worker has same environment variables as web
3. Check worker logs for errors

---

## Quick Reference: Render Free Tier Limits

- ✅ 750 hours/month uptime per service
- ✅ Apps sleep after 15 minutes of inactivity
- ✅ 100GB bandwidth/month
- ✅ 512MB RAM per service
- ✅ PostgreSQL: 1GB storage, 97 hours/month compute

**For production use, consider upgrading to paid plans.**

---

## Need Help?

- Render Docs: https://render.com/docs
- Render Community: https://community.render.com
- Rails Deployment Guide: https://guides.rubyonrails.org/

---

## Environment Variables Template

Save this for reference (fill in your values):

```bash
# Required
RAILS_MASTER_KEY=your_master_key_here
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
DATABASE_URL=(auto-set by Render)

# Optional (if not using Rails encrypted credentials)
GOOGLE_MAPS_API_KEY=your_key
STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_SECRET_KEY=sk_live_xxx
TWILIO_ACCOUNT_SID=ACxxx
TWILIO_AUTH_TOKEN=xxx
TWILIO_PHONE_NUMBER=+1234567890
USPS_USER_ID=xxx
ROLLBAR_ACCESS_TOKEN=xxx
```
