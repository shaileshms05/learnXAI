# Student AI Platform - Python Backend

This is the AI-powered backend for the Student AI Platform, built with FastAPI and **Google AI (Gemini 2.5 Flash)** as the primary AI provider, with optional Cerebras fallback.

## Features

- 🎓 **Learning Path Generator**: Personalized learning roadmaps
- 💼 **Internship Recommendations**: AI-curated opportunities
- 💬 **Career Guidance Chatbot**: 24/7 career advice
- 🤖 **Google AI (Gemini 2.5 Flash)**: Primary AI provider with state-of-the-art models
- ⚡ **Cerebras Fallback**: Optional ultra-fast inference fallback

## Tech Stack

- **Framework**: FastAPI
- **Primary AI**: Google AI (Gemini 2.5 Flash)
- **Fallback AI**: Cerebras AI (Llama 3.1) - Optional
- **Language**: Python 3.11+

## AI Provider Priority

1. **Google AI (Gemini 2.5 Flash)** - Primary (Required)
   - Get API key from: https://makersuite.google.com/app/apikey
   - Model: `gemini-2.5-flash` (fast, efficient, and powerful)
   - State-of-the-art performance with optimized speed and cost

2. **Cerebras AI** - Optional Fallback
   - Only used if Google AI is not available
   - Ultra-fast inference (10x faster than traditional GPUs)
   - Models: `llama3.1-8b` or `llama3.1-70b`

## Setup

### 1. Install Python Dependencies

```bash
cd ai-backend
pip install -r requirements.txt
```

Or use a virtual environment (recommended):

```bash
cd ai-backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Get Google AI API Key (Required)

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Copy the API key

### 3. (Optional) Get Cerebras API Key

Only needed if you want to use Cerebras as a fallback:

1. Go to [Cerebras Cloud](https://cloud.cerebras.ai/)
2. Sign up or log in
3. Navigate to **API Keys** section
4. Click **Create API Key**
5. Copy the API key

### 4. Configure Environment Variables

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

```env
# Required - Google AI (Gemini)
GOOGLE_API_KEY=your_google_api_key_here

# Optional - Cerebras AI (fallback)
# CEREBRAS_API_KEY=your_cerebras_api_key_here

# Firebase Configuration
FIREBASE_PROJECT_ID=student-app-36eec
PORT=8000
HOST=0.0.0.0
```

### 4. Run the Server

```bash
python main.py
```

Or with uvicorn directly:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at: `http://localhost:8000`

## API Documentation

Once the server is running, visit:
- **Interactive Docs**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc

## API Endpoints

### Health Check
```
GET /health
```

### Generate Learning Path
```
POST /api/ai/learning-path
```

**Request Body:**
```json
{
  "interests": ["AI", "Web Development"],
  "skills": ["Python", "JavaScript"],
  "careerGoal": "Full Stack Developer",
  "educationLevel": "Undergraduate",
  "timeCommitment": "10 hours/week"
}
```

### Get Internship Recommendations
```
POST /api/ai/internships
```

**Request Body:**
```json
{
  "skills": ["Python", "Machine Learning"],
  "interests": ["AI", "Data Science"],
  "location": "Remote",
  "experienceLevel": "Beginner"
}
```

### Chat with Career Advisor
```
POST /api/ai/chat
```

**Request Body:**
```json
{
  "message": "How do I prepare for a software engineering internship?",
  "context": {
    "educationLevel": "Undergraduate",
    "careerGoal": "Software Engineer",
    "skills": ["Python", "JavaScript"],
    "interests": ["Web Development"]
  }
}
```

## Testing with curl

### Test Learning Path Generation
```bash
curl -X POST "http://localhost:8000/api/ai/learning-path" \
  -H "Content-Type: application/json" \
  -d '{
    "interests": ["AI", "Web Development"],
    "skills": ["Python", "JavaScript"],
    "careerGoal": "Full Stack Developer",
    "educationLevel": "Undergraduate",
    "timeCommitment": "10 hours/week"
  }'
```

### Test Internship Recommendations
```bash
curl -X POST "http://localhost:8000/api/ai/internships" \
  -H "Content-Type: application/json" \
  -d '{
    "skills": ["Python", "Machine Learning"],
    "interests": ["AI", "Data Science"],
    "location": "Remote",
    "experienceLevel": "Beginner"
  }'
```

### Test Chat
```bash
curl -X POST "http://localhost:8000/api/ai/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "How do I prepare for a software engineering internship?"
  }'
```

## Integrating with Flutter App

Update your Flutter app's AI service to point to this backend:

```dart
// In lib/services/ai_service.dart
class AIService {
  final String baseUrl = 'http://localhost:8000'; // Or your deployed URL
  
  // ... rest of your code
}
```

## Deployment

### Deploy to Cloud Run (Google Cloud)

```bash
# Build and deploy
gcloud run deploy student-ai-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_API_KEY=your_key_here
```

### Deploy to Railway

1. Push to GitHub
2. Connect Railway to your repository
3. Add environment variables in Railway dashboard
4. Deploy!

### Deploy to Render

1. Create a new Web Service
2. Connect your repository
3. Set build command: `pip install -r requirements.txt`
4. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Add environment variables
6. Deploy!

## Development

### Hot Reload
The server automatically reloads when you make changes (if running with `--reload` flag).

### Adding New Endpoints
1. Add your endpoint function in `main.py`
2. Define Pydantic models for request/response
3. Test with `/docs` interface

## Troubleshooting

### "GOOGLE_API_KEY not found"
Make sure you've created a `.env` file with your API key.

### CORS Errors
If your Flutter app can't connect, check the `allow_origins` in the CORS middleware configuration.

### Port Already in Use
Change the port in `.env` or run with a different port:
```bash
PORT=8001 python main.py
```

## License

MIT

