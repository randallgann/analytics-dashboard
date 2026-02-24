# Cloud Run Deployment Guide

Deploy the Analytics Dashboard to Google Cloud Run as a standalone container. This is a demo app using SQLite — no external database or Redis required.

## Prerequisites

- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- A GCP project with billing enabled
- An Artifact Registry Docker repository:
  ```bash
  gcloud artifacts repositories create analytics-dashboard \
    --repository-format=docker \
    --location=us-central1
  ```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `RAILS_MASTER_KEY` | Yes | Contents of `config/master.key` |
| `GITHUB_TOKEN` | Yes | GitHub personal access token (public repo read access) |
| `SOLID_QUEUE_IN_PUMA` | Yes | Set to `true` — runs background jobs inside the web process |

## Build & Push

Set your project and region:

```bash
export PROJECT_ID=your-gcp-project
export REGION=us-central1
export IMAGE=$REGION-docker.pkg.dev/$PROJECT_ID/analytics-dashboard/app
```

Build and push the image:

```bash
docker build --platform linux/amd64 -t $IMAGE .
docker push $IMAGE
```

Or use Cloud Build to build remotely:

```bash
gcloud builds submit --tag $IMAGE
```

## Deploy

```bash
gcloud run deploy analytics-dashboard \
  --image $IMAGE \
  --region $REGION \
  --port 80 \
  --min-instances 1 \
  --max-instances 1 \
  --memory 512Mi \
  --allow-unauthenticated \
  --set-env-vars "SOLID_QUEUE_IN_PUMA=true" \
  --set-env-vars "RAILS_ENV=production" \
  --set-env-vars "GITHUB_TOKEN=your-github-token" \
  --set-secrets "RAILS_MASTER_KEY=rails-master-key:latest"
```

For the `RAILS_MASTER_KEY`, either pass it directly with `--set-env-vars` or store it in [Secret Manager](https://cloud.google.com/secret-manager) and reference it with `--set-secrets` as shown above. To create the secret:

```bash
echo -n "$(cat config/master.key)" | \
  gcloud secrets create rails-master-key --data-file=-
```

## Database Setup & Seeding

**Migrations** are handled automatically — the container entrypoint runs `db:prepare` on every startup.

**Seed historical data** by executing a one-off container after the first deploy:

```bash
gcloud run jobs execute analytics-dashboard-seed --wait 2>/dev/null || \
gcloud run jobs create analytics-dashboard-seed \
  --image $IMAGE \
  --region $REGION \
  --memory 512Mi \
  --set-env-vars "SOLID_QUEUE_IN_PUMA=true,RAILS_ENV=production,GITHUB_TOKEN=your-github-token" \
  --set-secrets "RAILS_MASTER_KEY=rails-master-key:latest" \
  --command "bin/rails" \
  --args "db:seed" \
  --execute-now --wait
```

Alternatively, use `gcloud run services exec` if your Cloud Run revision supports it, or simply let the recurring jobs populate fresh data over time (GitHub metrics every 6h, social feeds every 2h).

## Notes

- **SQLite is ephemeral on Cloud Run.** When the single instance restarts, the database resets and gets rebuilt from `db:prepare` + recurring jobs. This is acceptable for a demo — the seed data provides immediate chart history, and jobs backfill fresh data on schedule.
- **`min-instances=1`** keeps your container alive so the SQLite database persists between requests. Setting this to 0 means the database is lost on scale-down.
- **`max-instances=1`** prevents multiple instances from running separate SQLite databases.
- **Background jobs** (defined in `config/recurring.yml`) run inside Puma via Solid Queue:
  - `GithubMetricJob` — every 6 hours
  - `HnSocialJob` — every 2 hours
  - `RedditSocialJob` — every 2 hours
  - `DataRetentionJob` — daily at 3am

## Verify

After deploying, confirm everything is working:

```bash
# Get the service URL
SERVICE_URL=$(gcloud run services describe analytics-dashboard \
  --region $REGION --format "value(status.url)")

# Health check
curl -s $SERVICE_URL/up
# Should return 200

# Open dashboard
open $SERVICE_URL
```

The dashboard should load with charts populated from seed data. Live data will appear after the first scheduled job runs.
