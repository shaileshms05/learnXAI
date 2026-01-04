# Deployment Configuration

This folder contains all files needed for deploying the Student AI Platform backend to Google Cloud Platform.

## Files

- **`deploy.sh`** - Automated deployment script
- **`cloudbuild.yaml`** - Cloud Build configuration for CI/CD
- **`docker-compose.yml`** - Local testing with Docker Compose
- **`DEPLOYMENT.md`** - Comprehensive deployment guide
- **`.env.example`** - Environment variables template

## Quick Start

### Prerequisites

1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
2. Install Docker: https://docs.docker.com/get-docker/
3. Set up GCP project with billing enabled

### Deploy

```bash
# Set your project ID
export GCP_PROJECT_ID=your-project-id

# Run deployment script
chmod +x deploy.sh
./deploy.sh
```

## Environment Variables

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
# Edit .env with your values
```

Required variables:
- `GOOGLE_API_KEY` - Google AI (Gemini) API key
- `FIREBASE_PROJECT_ID` - Firebase project ID
- `GCP_PROJECT_ID` - GCP project ID

Optional variables:
- `CEREBRAS_API_KEY` - Cerebras API key (fallback)

## Local Testing

Test the Docker image locally:

```bash
docker-compose up --build
```

The service will be available at: http://localhost:8080

## Documentation

See `DEPLOYMENT.md` for detailed deployment instructions.

