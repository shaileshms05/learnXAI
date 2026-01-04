#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if API key is set
if [ -z "$CEREBRAS_API_KEY" ]; then
    echo "⚠️  WARNING: CEREBRAS_API_KEY not set!"
    echo "Book learning features will not work."
else
    echo "✅ CEREBRAS_API_KEY is set"
fi

# Kill any existing server
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
sleep 1

# Start server
echo "🚀 Starting server..."
python3 main.py

