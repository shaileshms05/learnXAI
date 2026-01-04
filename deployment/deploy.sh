#!/bin/bash

# Student AI Platform - GCP Deployment Script
# This script deploys the backend to Google Cloud Run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-student-app-36eec}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="student-ai-backend"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Student AI Platform - GCP Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if user is authenticated
echo -e "${YELLOW}Checking authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${YELLOW}⚠️  Not authenticated. Please login...${NC}"
    gcloud auth login
fi

# Set the project
echo -e "${YELLOW}Setting GCP project to: ${PROJECT_ID}${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable secretmanager.googleapis.com

# Check if secrets exist, create if not
echo -e "${YELLOW}Checking secrets...${NC}"

# Google API Key
if ! gcloud secrets describe google-api-key --project=${PROJECT_ID} &> /dev/null; then
    echo -e "${YELLOW}Creating google-api-key secret...${NC}"
    read -sp "Enter your Google API Key (Gemini): " GOOGLE_KEY
    echo ""
    echo -n "${GOOGLE_KEY}" | gcloud secrets create google-api-key \
        --data-file=- \
        --project=${PROJECT_ID} \
        --replication-policy="automatic"
else
    echo -e "${GREEN}✅ google-api-key secret exists${NC}"
fi

# Cerebras API Key (optional)
if ! gcloud secrets describe cerebras-api-key --project=${PROJECT_ID} &> /dev/null; then
    echo -e "${YELLOW}Cerebras API Key (optional - press Enter to skip):${NC}"
    read -sp "Enter your Cerebras API Key (or press Enter to skip): " CEREBRAS_KEY
    echo ""
    if [ ! -z "$CEREBRAS_KEY" ]; then
        echo -n "${CEREBRAS_KEY}" | gcloud secrets create cerebras-api-key \
            --data-file=- \
            --project=${PROJECT_ID} \
            --replication-policy="automatic"
        echo -e "${GREEN}✅ cerebras-api-key secret created${NC}"
    fi
else
    echo -e "${GREEN}✅ cerebras-api-key secret exists${NC}"
fi

# Firebase Project ID
if ! gcloud secrets describe firebase-project-id --project=${PROJECT_ID} &> /dev/null; then
    echo -e "${YELLOW}Creating firebase-project-id secret...${NC}"
    echo -n "${PROJECT_ID}" | gcloud secrets create firebase-project-id \
        --data-file=- \
        --project=${PROJECT_ID} \
        --replication-policy="automatic"
else
    echo -e "${GREEN}✅ firebase-project-id secret exists${NC}"
fi

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
cd "$(dirname "$0")/.."
docker build -t ${IMAGE_NAME}:latest -f ai-backend/Dockerfile ai-backend/

# Push the image to Container Registry
echo -e "${YELLOW}Pushing image to Container Registry...${NC}"
docker push ${IMAGE_NAME}:latest

# Deploy to Cloud Run
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME}:latest \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --timeout 300 \
    --set-env-vars PORT=8080 \
    --set-secrets GOOGLE_API_KEY=google-api-key:latest,CEREBRAS_API_KEY=cerebras-api-key:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest \
    --project ${PROJECT_ID}

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)' \
    --project ${PROJECT_ID})

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Service URL: ${GREEN}${SERVICE_URL}${NC}"
echo -e "API Docs: ${GREEN}${SERVICE_URL}/docs${NC}"
echo -e "Health Check: ${GREEN}${SERVICE_URL}/health${NC}"
echo ""
echo -e "${YELLOW}To update your Flutter app, use this URL as your backend base URL.${NC}"

