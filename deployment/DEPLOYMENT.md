# Student AI Platform - Production Deployment Guide

This guide covers deploying the Student AI Platform backend to Google Cloud Platform (GCP) using Docker and Cloud Run.

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Docker** installed and running
4. **API Keys**:
   - Google AI (Gemini) API Key (Required)
   - Cerebras API Key (Optional, fallback)
   - Firebase Project ID

## Quick Start

### Option 1: Automated Deployment Script

```bash
cd deployment
chmod +x deploy.sh
export GCP_PROJECT_ID=your-project-id
./deploy.sh
```

### Option 2: Manual Deployment

Follow the steps below for manual deployment.

## Step-by-Step Deployment

### 1. Set Up GCP Project

```bash
# Set your project ID
export GCP_PROJECT_ID=your-project-id
gcloud config set project $GCP_PROJECT_ID

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

### 2. Configure Secrets

Store your API keys securely in Google Secret Manager:

```bash
# Google API Key (Required)
echo -n "your-google-api-key" | gcloud secrets create google-api-key \
    --data-file=- \
    --replication-policy="automatic"

# Cerebras API Key (Optional)
echo -n "your-cerebras-api-key" | gcloud secrets create cerebras-api-key \
    --data-file=- \
    --replication-policy="automatic"

# Firebase Project ID
echo -n "your-firebase-project-id" | gcloud secrets create firebase-project-id \
    --data-file=- \
    --replication-policy="automatic"
```

### 3. Build Docker Image

```bash
# From project root
docker build -t gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest \
    -f ai-backend/Dockerfile \
    ai-backend/
```

### 4. Push to Container Registry

```bash
# Authenticate Docker with GCR
gcloud auth configure-docker

# Push the image
docker push gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest
```

### 5. Deploy to Cloud Run

```bash
gcloud run deploy student-ai-backend \
    --image gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --timeout 300 \
    --set-env-vars PORT=8080 \
    --set-secrets GOOGLE_API_KEY=google-api-key:latest,CEREBRAS_API_KEY=cerebras-api-key:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest
```

### 6. Get Service URL

```bash
gcloud run services describe student-ai-backend \
    --platform managed \
    --region us-central1 \
    --format 'value(status.url)'
```

## Using Cloud Build (CI/CD)

For automated deployments using Cloud Build:

```bash
# Submit build
gcloud builds submit --config deployment/cloudbuild.yaml
```

## Environment Variables

The following environment variables are configured:

| Variable | Source | Required | Description |
|----------|--------|----------|-------------|
| `GOOGLE_API_KEY` | Secret Manager | Yes | Google AI (Gemini) API key |
| `CEREBRAS_API_KEY` | Secret Manager | No | Cerebras API key (fallback) |
| `FIREBASE_PROJECT_ID` | Secret Manager | Yes | Firebase project ID |
| `PORT` | Environment | Yes | Server port (default: 8080) |

## Cloud Run Configuration

- **Memory**: 2Gi
- **CPU**: 2 vCPU
- **Min Instances**: 0 (scales to zero)
- **Max Instances**: 10
- **Timeout**: 300 seconds
- **Port**: 8080
- **Platform**: Managed

## Updating Deployment

### Update Secrets

```bash
# Update Google API Key
echo -n "new-key" | gcloud secrets versions add google-api-key --data-file=-

# Update Cerebras API Key
echo -n "new-key" | gcloud secrets versions add cerebras-api-key --data-file=-
```

### Redeploy

```bash
# Rebuild and push
docker build -t gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest \
    -f ai-backend/Dockerfile ai-backend/
docker push gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest

# Redeploy
gcloud run deploy student-ai-backend \
    --image gcr.io/$GCP_PROJECT_ID/student-ai-backend:latest \
    --region us-central1
```

## Monitoring and Logs

### View Logs

```bash
gcloud run services logs read student-ai-backend \
    --region us-central1 \
    --limit 50
```

### Monitor in Console

Visit: https://console.cloud.google.com/run

## Health Check

The service includes a health check endpoint:

```bash
curl https://your-service-url/health
```

## Troubleshooting

### Container fails to start

1. Check logs: `gcloud run services logs read student-ai-backend --region us-central1`
2. Verify secrets are set correctly
3. Check Dockerfile for any build issues

### API key errors

1. Verify secrets exist: `gcloud secrets list`
2. Check secret versions: `gcloud secrets versions access latest --secret=google-api-key`
3. Ensure secrets are attached to Cloud Run service

### Timeout issues

Increase timeout:
```bash
gcloud run services update student-ai-backend \
    --timeout 600 \
    --region us-central1
```

### Memory issues

Increase memory:
```bash
gcloud run services update student-ai-backend \
    --memory 4Gi \
    --region us-central1
```

## Cost Estimation

Approximate monthly costs (varies by usage):

- **Cloud Run**: ~$10-50/month (pay per use, scales to zero)
- **Container Registry**: ~$0.10/GB/month
- **Secret Manager**: Free tier covers most use cases

## Security Best Practices

1. ✅ Secrets stored in Secret Manager (not in code)
2. ✅ HTTPS enforced by Cloud Run
3. ✅ IAM roles configured
4. ✅ Container image scanning enabled
5. ✅ VPC connector for private resources (optional)

## Next Steps

1. Set up custom domain (optional)
2. Configure Cloud CDN for caching
3. Set up monitoring alerts
4. Configure backup strategy for persistent data

## Support

For issues or questions:
- Check logs: `gcloud run services logs read student-ai-backend`
- Review Cloud Run documentation: https://cloud.google.com/run/docs

