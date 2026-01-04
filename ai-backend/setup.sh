#!/bin/bash

echo "=================================="
echo "Student AI Platform - Backend Setup"
echo "=================================="
echo ""
echo "Step 1: Get your Cerebras API Key"
echo "---------------------------------------"
echo "1. Go to: https://cloud.cerebras.ai/"
echo "2. Sign up or log in"
echo "3. Navigate to 'API Keys' section"
echo "4. Click 'Create API Key'"
echo "5. Copy the API key"
echo ""
echo "Step 2: Configure the backend"
echo "-----------------------------"
echo ""
read -p "Paste your Cerebras API Key: " api_key
echo ""

# Update the .env file
cat > .env << EOF
# Cerebras API Key
CEREBRAS_API_KEY=$api_key

# Firebase Service Account
FIREBASE_PROJECT_ID=student-app-36eec

# Server Configuration
PORT=8000
HOST=0.0.0.0
EOF

echo "✅ Configuration saved!"
echo ""
echo "Step 3: Start the server"
echo "------------------------"
echo "Run: python3 main.py"
echo ""
echo "Or run with auto-reload (for development):"
echo "Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "The API will be available at: http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"
echo ""
echo "Why Cerebras? ⚡"
echo "- Ultra-fast inference (10x faster than traditional GPUs)"
echo "- Cost-effective pricing"
echo "- Llama 3.1 70B model for high-quality responses"
echo ""

