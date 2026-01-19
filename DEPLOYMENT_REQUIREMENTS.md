# Tree Recycle App - Deployment Requirements & Components

## Executive Summary

**Can Render.com handle everything?**
**Short answer: Almost, but not quite.** Render can handle the app hosting, database, and worker processes, but you need several external third-party services for full functionality.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    RENDER.COM (Free Tier)                   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  Web Server  │  │  PostgreSQL  │  │  Worker Process │   │
│  │  (Puma)      │  │  Database    │  │  (Delayed Job)  │   │
│  │              │  │              │  │                 │   │
│  │  Rails 7     │  │  1GB Storage │  │  Background     │   │
│  │  512MB RAM   │  │  Free Tier   │  │  Tasks          │   │
│  └──────┬───────┘  └──────────────┘  └─────────────────┘   │
└─────────┼───────────────────────────────────────────────────┘
          │
          │ Connects to External Services:
          │
          ├─► Google Maps API (Required - Paid)
          ├─► AWS Location Service (Required - Paid)
          ├─► Stripe (Required - Paid/Free Tier)
          ├─► Twilio (Required - Paid)
          ├─► USPS API (Optional - Free)
          ├─► Rollbar (Optional - Free Tier)
          └─► Gmail SMTP (Required - Free)
```

## Required Components Breakdown

### 1. **Render.com Services** ✅ (Render Provides)

#### Web Service (Free Tier)
- **What it does**: Runs your Rails application
- **Specifications**:
  - Runtime: Ruby 3.0.2
  - Server: Puma
  - RAM: 512MB
  - Storage: Ephemeral (files don't persist across deploys)
  - Network: Free SSL certificate included
  - Uptime: Sleeps after 15 minutes of inactivity
- **Cost**: Free (with limitations)
- **Render provides**: ✅ Yes, fully managed

#### PostgreSQL Database (Free Tier)
- **What it does**: Stores all application data
  - User accounts
  - Reservations (tree pickups)
  - Routes and zones
  - Donation records
  - Background job queue
  - Application logs
- **Specifications**:
  - Storage: 1GB
  - Uptime: 97 hours/month active
  - Expires after 90 days of inactivity
- **Cost**: Free (with limitations)
- **Render provides**: ✅ Yes, fully managed

#### Worker Service (Free Tier)
- **What it does**: Processes background jobs
  - Geocoding addresses (converting addresses to lat/long)
  - Sending delayed SMS notifications
  - Processing batch operations
  - Cleanup tasks
- **How it works**: Uses DelayedJob with database backend
  - Jobs stored in `delayed_jobs` table
  - Worker polls database for new jobs
  - Runs `rake jobs:work` continuously
- **Cost**: Free (with limitations)
- **Render provides**: ✅ Yes, fully managed

---

### 2. **External APIs - REQUIRED** ❌ (You Must Provide)

#### Google Maps API (Required)
- **What it does**:
  - Displays interactive maps showing tree locations
  - Shows routes and zones on map
  - User location and navigation
  - Marker clustering and info windows
- **Where used**:
  - `/driver/reservations/map` - Driver map view
  - `/admin/reservations/map` - Admin map view
  - All reservation location displays
- **Cost**:
  - Free tier: $200 credit/month (~28,000 map loads)
  - Pay-as-you-go after free tier
  - Typical usage for small org: Stays within free tier
- **Setup Required**:
  1. Create Google Cloud Platform account
  2. Enable Maps JavaScript API
  3. Create API key
  4. Restrict key to your domain (security)
- **Can you skip it?**: ❌ No - Core feature
- **Render handles?**: ❌ No - External service

#### AWS Location Service (Required)
- **What it does**: Geocoding (address → latitude/longitude)
  - Converts street addresses to GPS coordinates
  - Validates and standardizes addresses
  - Powers the map plotting functionality
- **Where used**:
  - When creating new reservations
  - When editing reservation addresses
  - Background jobs that geocode addresses
  - Route optimization calculations
- **Why AWS instead of Google?**:
  - More accurate for US addresses
  - Better privacy controls
  - More cost-effective for geocoding volume
- **Cost**:
  - First 50,000 requests/month: Free
  - After: $0.50 per 1,000 requests
  - Typical usage: Stays within free tier
- **Setup Required**:
  1. Create AWS account
  2. Enable Amazon Location Service
  3. Create Place Index named 'tree_recycle'
  4. Create IAM user with permissions
  5. Generate access keys
- **Can you skip it?**: ❌ No - Required for address mapping
- **Render handles?**: ❌ No - External service

#### Stripe (Required)
- **What it does**: Payment processing
  - Accept online donations from residents
  - Credit card processing
  - Payment intent management
  - Refunds and payment history
- **Where used**:
  - `/reservations/:id` - Donation form
  - Online donation checkout flow
  - Payment confirmation emails
- **Cost**:
  - No monthly fee
  - 2.9% + $0.30 per successful transaction
  - No charge for failed transactions
- **Setup Required**:
  1. Create Stripe account
  2. Complete business verification
  3. Get publishable key (frontend)
  4. Get secret key (backend)
  5. Configure webhooks (optional)
- **Can you skip it?**: ⚠️ Partially
  - Online donations won't work
  - Cash/check donations still work
  - Would need to disable online payment option
- **Render handles?**: ❌ No - External service

#### Twilio (Required)
- **What it does**: SMS messaging
  - Send SMS to residents when tree is marked "Missing"
  - Notification when reservation status changes
  - Appointment reminders (if configured)
  - Driver communication
- **Where used**:
  - When marking reservation as "Missing" on map
  - Background job for scheduled notifications
  - Status update notifications
- **Cost**:
  - Pay-as-you-go
  - $0.0079 per SMS in US
  - Must maintain minimum $20 balance
  - Typical usage: $10-30/month for small org
- **Setup Required**:
  1. Create Twilio account
  2. Get a phone number (~$1/month)
  3. Get Account SID
  4. Get Auth Token
  5. Verify number capabilities
- **Can you skip it?**: ⚠️ Partially
  - SMS notifications won't work
  - Would need to communicate via email instead
  - Core app still functional
- **Render handles?**: ❌ No - External service

---

### 3. **External APIs - OPTIONAL** (Nice to Have)

#### USPS Address Validation API (Optional)
- **What it does**: Validates US postal addresses
  - Checks if address exists
  - Standardizes address format
  - Suggests corrections for typos
- **Where used**:
  - When creating/editing reservations
  - Address autocomplete (if enabled)
- **Cost**: Free
- **Setup Required**:
  1. Register at USPS Web Tools
  2. Request API access
  3. Get User ID
- **Can you skip it?**: ✅ Yes
  - App works without it
  - Address validation less strict
  - May accept invalid addresses
- **Render handles?**: ❌ No - External service

#### Rollbar (Optional)
- **What it does**: Error tracking and monitoring
  - Captures application errors
  - Provides stack traces
  - Sends alerts for critical errors
  - Performance monitoring
- **Where used**:
  - Throughout application
  - Catches unhandled exceptions
  - Monitors production issues
- **Cost**:
  - Free tier: 5,000 events/month
  - Good for small deployments
- **Setup Required**:
  1. Create Rollbar account
  2. Create new project
  3. Get access token
- **Can you skip it?**: ✅ Yes
  - Errors go to Rails logs instead
  - Harder to track issues
  - Recommended for production
- **Render handles?**: ❌ No - External service

#### Redis (Optional - Currently Not Used)
- **What it does**: In-memory data store
  - Caching
  - Session storage
  - Real-time features
- **Current status**:
  - Gem is installed
  - Initializer exists
  - **NOT actually used in app code**
- **Can you skip it?**: ✅ Yes
  - Not currently functional
  - Can be removed or left as-is
  - May be for future features
- **Render provides**: ✅ Yes (if needed)
  - Free tier available
  - Can add via Render dashboard

---

### 4. **Email Service** (Required)

#### Gmail SMTP (Required)
- **What it does**: Sends transactional emails
  - Reservation confirmations
  - Password resets
  - Admin notifications
  - Receipt emails
- **Cost**: Free (with Gmail account)
- **Setup Required**:
  1. Use existing Gmail account or create new
  2. Enable 2-factor authentication
  3. Create App Password
  4. Configure in credentials
- **Can you skip it?**: ❌ No
  - User authentication requires email
  - Password resets won't work
  - No confirmation emails
- **Render handles?**: ❌ No - External service
- **Alternatives**:
  - SendGrid (free tier: 100 emails/day)
  - Mailgun (free tier: 5,000 emails/month)
  - Amazon SES (very cheap)

---

## What Render.com CAN and CANNOT Do

### ✅ What Render CAN Provide

1. **Application Hosting**
   - Ruby/Rails runtime environment
   - Web server (Puma)
   - SSL certificates
   - Custom domains
   - Automatic deployments from GitHub

2. **Database Hosting**
   - Managed PostgreSQL
   - Automatic backups
   - Connection pooling
   - Database URL management

3. **Worker Processes**
   - Background job processing
   - Scheduled tasks
   - Separate worker instances

4. **Infrastructure**
   - Load balancing
   - DDoS protection
   - CDN for static assets
   - Monitoring dashboards
   - Log aggregation

5. **Optional Services** (if you upgrade)
   - Redis (for caching)
   - Cron jobs
   - Increased resources
   - Always-on instances (no sleeping)

### ❌ What Render CANNOT Provide

1. **Third-Party API Access**
   - Cannot provide Google Maps API
   - Cannot provide AWS credentials
   - Cannot provide Twilio account
   - Cannot provide Stripe account

2. **API Keys/Credentials**
   - You must create your own accounts
   - You must obtain your own API keys
   - You manage your own usage/billing

3. **Business Logic Services**
   - Cannot do geocoding (need AWS)
   - Cannot send SMS (need Twilio)
   - Cannot process payments (need Stripe)
   - Cannot display maps (need Google)

4. **Free Tier Limitations**
   - Cannot prevent app sleeping (15 min inactivity)
   - Cannot provide more than 512MB RAM
   - Cannot provide more than 1GB database storage
   - Cannot provide guaranteed uptime

---

## Complete Setup Checklist

### Phase 1: External Services (Do First)

- [ ] **Google Maps API**
  - [ ] Create GCP account
  - [ ] Enable Maps JavaScript API
  - [ ] Create and restrict API key
  - [ ] Test map loading

- [ ] **AWS Location Service**
  - [ ] Create AWS account
  - [ ] Enable Amazon Location Service
  - [ ] Create Place Index: 'tree_recycle'
  - [ ] Create IAM user with location permissions
  - [ ] Generate access key ID and secret

- [ ] **Stripe**
  - [ ] Create Stripe account
  - [ ] Complete business verification
  - [ ] Get test keys for testing
  - [ ] Get live keys for production
  - [ ] Configure webhook endpoints (optional)

- [ ] **Twilio**
  - [ ] Create Twilio account
  - [ ] Purchase phone number
  - [ ] Get Account SID
  - [ ] Get Auth Token
  - [ ] Add balance ($20 minimum recommended)

- [ ] **Gmail SMTP** (or alternative)
  - [ ] Use existing Gmail or create new
  - [ ] Enable 2FA
  - [ ] Create App Password
  - [ ] Test SMTP connection

- [ ] **Optional: USPS API**
  - [ ] Register at USPS Web Tools
  - [ ] Request API access
  - [ ] Get User ID

- [ ] **Optional: Rollbar**
  - [ ] Create Rollbar account
  - [ ] Create project
  - [ ] Get access token

### Phase 2: Rails Credentials

- [ ] **Setup credentials.yml.enc**
  - [ ] Use existing master key OR
  - [ ] Generate new credentials file
  - [ ] Add all API keys and credentials
  - [ ] Save RAILS_MASTER_KEY securely

### Phase 3: Render.com Deployment

- [ ] **Create Render Account**
  - [ ] Sign up with GitHub
  - [ ] Connect repository

- [ ] **Deploy from Blueprint**
  - [ ] Select tree-recycle repo
  - [ ] Apply render.yaml
  - [ ] Wait for service creation

- [ ] **Configure Environment Variables**
  - [ ] Add RAILS_MASTER_KEY
  - [ ] Verify DATABASE_URL is auto-set
  - [ ] Add to both web and worker services

- [ ] **Deploy Application**
  - [ ] Trigger manual deploy
  - [ ] Monitor build logs
  - [ ] Verify migrations ran

- [ ] **Test Deployment**
  - [ ] Access public URL
  - [ ] Test user login
  - [ ] Test map display
  - [ ] Test geocoding
  - [ ] Test payment (Stripe test mode)
  - [ ] Test SMS (small test)

---

## Cost Breakdown (Monthly)

### Free Tier (Render.com)
| Service | Free Tier | Limitations |
|---------|-----------|-------------|
| Web App | ✅ Free | Sleeps after 15 min, 512MB RAM |
| Database | ✅ Free | 1GB storage, 97 hrs/month |
| Worker | ✅ Free | 750 hrs/month |
| **Total** | **$0** | Good for testing/low traffic |

### External Services (Required)
| Service | Free Tier | Typical Cost |
|---------|-----------|--------------|
| Google Maps | $200/month credit | $0-10/month (small org) |
| AWS Location | 50k requests free | $0-5/month (small org) |
| Stripe | No monthly fee | 2.9% + $0.30 per transaction |
| Twilio | None | $10-30/month (depends on SMS volume) |
| Gmail SMTP | ✅ Free | $0 |
| **Total** | - | **~$10-40/month** (small org) |

### Optional Services
| Service | Cost |
|---------|------|
| USPS API | ✅ Free |
| Rollbar | ✅ Free (5k events) |
| Redis (if added) | ✅ Free on Render |

### **Total Monthly Cost Estimate**
- **Minimum**: $10-15/month (just Twilio + occasional AWS/Google overages)
- **Typical Small Org**: $20-40/month
- **Medium Org**: $50-100/month (more SMS, more map loads)

### Scaling Costs (If Needed)
| Upgrade | Cost | Benefit |
|---------|------|---------|
| Render Web (Starter) | $7/month | Always-on, no sleeping |
| Render DB (Starter) | $7/month | 10GB storage, full uptime |
| Render Worker (Starter) | $7/month | Always-on background jobs |
| **Total Upgrade** | **$21/month** | Professional-grade hosting |

---

## Why Does AWS Only Handle Geocoding?

### What is Geocoding?
Geocoding is converting addresses to coordinates:
```
"123 Main St, Seattle, WA 98101"
    ↓ (geocoding)
Latitude: 47.6062, Longitude: -122.3321
```

### Why It's Needed
1. **Map Display**: Can't plot markers without lat/long
2. **Route Optimization**: Can't calculate distances without coordinates
3. **Location Services**: User location needs to relate to addresses

### Why AWS Location Service?
- **Accuracy**: Better US address recognition than Google
- **Cost**: More affordable for high-volume geocoding
- **Privacy**: Data stays in your AWS account
- **Reliability**: Proven enterprise-grade service

### What AWS Does NOT Do
- ❌ Does not display maps (Google Maps does this)
- ❌ Does not track user location (browser Geolocation API does this)
- ❌ Does not store location data (PostgreSQL does this)
- ❌ Only converts addresses → coordinates

### Could You Use Google Instead?
Yes, but:
- Google Geocoding API is more expensive
- Less accurate for some US addresses
- Would simplify to one vendor (Google)
- Change would require code modification

---

## Alternatives to AWS Location Service

If you want to avoid AWS entirely:

### Option 1: Google Geocoding API
**Pros:**
- One vendor (Google) for maps + geocoding
- Good global coverage
- Simple setup

**Cons:**
- More expensive ($5 per 1,000 requests vs AWS free tier)
- May be less accurate for US addresses

**Code changes needed:**
```ruby
# config/initializers/geocoder.rb
Geocoder.configure(
  lookup: :google,  # Change from :amazon_location_service
  api_key: ENV['GOOGLE_MAPS_API_KEY']
)
```

### Option 2: Nominatim (OpenStreetMap) - FREE
**Pros:**
- ✅ Completely free
- No API key needed
- Open source

**Cons:**
- Lower accuracy than AWS/Google
- Usage limits (1 request/second)
- Less reliable for US addresses
- May need to self-host for higher volume

**Code changes needed:**
```ruby
# config/initializers/geocoder.rb
Geocoder.configure(
  lookup: :nominatim,
  timeout: 10
)
```

### Option 3: Mapbox
**Pros:**
- Generous free tier (100k requests/month)
- Could replace Google Maps too
- Modern API

**Cons:**
- Requires new account
- Different map SDK (major code changes)

---

## Minimum Viable Deployment

If you want to deploy with **absolute minimum** external services:

### Scenario: Deploy for Testing/Demo

**Required:**
- ✅ Render.com (web + database)
- ✅ Google Maps API (can't avoid - core feature)
- ✅ Gmail SMTP (password resets need email)
- ✅ AWS Location Service OR Nominatim (geocoding)

**Can Skip for Testing:**
- ❌ Stripe (disable online donations)
- ❌ Twilio (disable SMS notifications)
- ❌ USPS (disable address validation)
- ❌ Rollbar (use Rails logs)

**Configuration:**
```ruby
# Disable SMS in app
Setting.first.update(is_sms_enabled: false)

# Hide online donation option
# (manual config or code change)
```

**Cost**: $0 Render + $0 Google (free tier) + $0 Gmail = **$0/month**

---

## Summary: Can Render Do Everything?

### ✅ YES - Render Provides:
- Application hosting (web server)
- Database (PostgreSQL)
- Background workers
- SSL, domains, deployments
- Infrastructure management

### ❌ NO - You Must Provide:
- **Google Maps API** - Absolutely required, no alternative
- **AWS Location Service** - Required for geocoding (or use alternative)
- **Stripe** - Required for payments (can disable feature)
- **Twilio** - Required for SMS (can disable feature)
- **Gmail** - Required for emails

### 🎯 Bottom Line

**Render.com is the foundation, but the app needs external services to work.**

Think of it like building a house:
- **Render** = The foundation and structure (hosting, database, server)
- **External APIs** = The utilities (electricity, water, internet)

You need both for a functional application!

---

## Next Steps

1. **Gather all API credentials first** (see Phase 1 checklist)
2. **Configure Rails credentials** with all keys
3. **Deploy to Render** using blueprint
4. **Test each integration** systematically
5. **Monitor costs** in first month
6. **Optimize** as needed

Need help with any specific service setup? Let me know!
