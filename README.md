# 🎓 Student AI Platform - GDG Hackathon Project

<div align="center">

![GDG Hackathon](https://img.shields.io/badge/GDG-Hackathon-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109-green)
![Google AI](https://img.shields.io/badge/Google%20AI-Gemini%202.5%20Flash-orange)
![Firebase](https://img.shields.io/badge/Firebase-Hosted-yellow)

**An AI-powered educational platform helping students learn, find internships, and advance their careers**

[Features](#-features) • [Architecture](#️-architecture) • [Google Tools](#-google-tools--services) • [Setup](#-getting-started) • [Deployment](#-deployment)

</div>

---

## 📋 Project Overview

**Student AI Platform** is a comprehensive, AI-powered educational and career development application designed to help students learn, find internships, and advance their careers. Built for the GDG Hackathon, this platform combines modern web technologies, Google AI capabilities, and cross-platform mobile development to deliver a seamless user experience.

### 🎯 Core Objectives

- **Personalized Learning**: AI-generated learning paths tailored to individual goals
- **Career Development**: Intelligent internship discovery and job application assistance
- **Skill Enhancement**: Interactive book learning with AI-powered teaching
- **Interview Preparation**: Voice-based mock interviews with real-time feedback
- **Resume Optimization**: AI-powered resume analysis and optimization

---

## 🏗️ Architecture

### System Architecture: Multi-Tier Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend Layer                            │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │ Flutter App  │         │ Next.js Web  │                  │
│  │  (Mobile)    │         │  (Desktop)   │                  │
│  │ iOS/Android/ │         │              │                  │
│  │    Web       │         │              │                  │
│  └──────┬───────┘         └──────┬───────┘                 │
│         │                        │                          │
│         └────────────┬───────────┘                          │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
┌──────────────────────┼──────────────────────────────────────┐
│              Backend API Layer (FastAPI)                       │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         FastAPI REST API Server                      │    │
│  │  - Learning Path Generation                          │    │
│  │  - Internship Scraping                               │    │
│  │  - Resume Analysis & Optimization                    │    │
│  │  - Mock Interview System                             │    │
│  │  - Book Learning System (RAG)                        │    │
│  │  - Job Application Agent                             │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────┼──────────────────────────────────────┘
                       │
┌──────────────────────┼──────────────────────────────────────┐
│              Google Services & External APIs                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Google AI    │  │   Firebase   │  │   Google     │      │
│  │ (Gemini 2.5  │  │  (Auth,      │  │   Calendar   │      │
│  │   Flash)     │  │  Firestore)  │  │   API        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                          │
│  │  AI       │  │   Gmail API │                          │
│  │ (Enterprise) │  │             │                          │
│  └──────────────┘  └──────────────┘                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 🤖 Core AI/ML Technologies

### 1. **Google AI (Gemini 2.5 Flash)** - Primary AI Provider

**Technology**: Large Language Model (LLM)  
**Model**: `gemini-2.5-flash`  
**Purpose**: Primary AI engine for all intelligent features

**Key Applications**:
- **Learning Path Generation**: Creates personalized learning roadmaps
- **Resume Analysis**: Analyzes and optimizes resumes with AI insights
- **Interview Questions**: Generates contextual interview questions
- **Job Application Emails**: Crafts professional application emails
- **Career Guidance**: Provides 24/7 career advice through chatbot
- **Book Learning**: Extracts concepts and generates teaching content

**Implementation**:
```python
# Unified AI Client with Google AI
from ai_client import UnifiedAIClient

ai_client = UnifiedAIClient()  # Auto-detects Google AI
response = ai_client.chat_completions_create(
    model="gemini-2.5-flash",
    messages=[{"role": "user", "content": "Generate a learning path..."}]
)
```

**Why Gemini 2.5 Flash?**
- ⚡ **Fast**: Optimized for speed and efficiency
- 💰 **Cost-Effective**: Lower cost per token
- 🎯 **Accurate**: State-of-the-art performance
- 🔄 **Multimodal**: Supports text, images, and more



### 2. **RAG (Retrieval-Augmented Generation)**

**Technology**: ChromaDB + Sentence Transformers  
**Purpose**: Context-aware AI responses for book learning

**Architecture**:
```
PDF Upload → Text Extraction → Chunking → 
Vector Embeddings → ChromaDB Storage → 
Semantic Search → Context Retrieval → 
AI Response Generation
```

**Key Components**:
- **Vector Database**: ChromaDB for storing embeddings
- **Embeddings**: Sentence Transformers for semantic search
- **Knowledge Graph**: Concept extraction and relationships
- **Context Retrieval**: RAG pipeline for relevant information

### 3. **Vector Embeddings**

**Technology**: Sentence Transformers  
**Purpose**: Semantic search and concept matching

**Applications**:
- Book content search
- Concept extraction
- Knowledge retrieval
- Similarity matching

### 4. **Knowledge Graphs**

**Technology**: Graph Data Structures  
**Purpose**: Represent concept relationships

**Features**:
- Concept extraction from books
- Relationship mapping
- Prerequisite tracking
- Learning path optimization

---

## 🔧 Google Tools & Services

### 1. **Google AI (Gemini API)**

**Service**: Google Generative AI  
**API**: `google-generativeai`  
**Usage**: Primary AI provider for all intelligent features

**Integration**:
```python
import google.generativeai as genai

genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel('gemini-2.5-flash')
response = model.generate_content("Generate learning path...")
```

**Features Used**:
- Text generation
- Chat completions
- Content analysis
- Multi-turn conversations

### 2. **Firebase Authentication**

**Service**: Firebase Auth  
**Package**: `firebase_auth` (Flutter), `firebase-admin` (Python)  
**Usage**: User authentication and authorization

**Features**:
- Email/Password authentication
- Google Sign-In integration
- User session management
- Secure token handling

**Implementation**:
```dart
// Flutter
final authProvider = Provider.of<AuthProvider>(context);
await authProvider.signInWithGoogle();
```

### 3. **Cloud Firestore**

**Service**: Firebase Firestore  
**Package**: `cloud_firestore` (Flutter), `firebase-admin` (Python)  
**Usage**: NoSQL database for user data and application state

**Data Stored**:
- User profiles
- Learning paths
- Daily tasks
- Book progress
- Interview history
- Resume data

**Features**:
- Real-time synchronization
- Offline support
- Scalable NoSQL structure
- Security rules

### 4. **Google Calendar API**

**Service**: Google Calendar  
**Package**: `googleapis/calendar`  
**Usage**: Automatic task scheduling and calendar integration

**Features**:
- OAuth 2.0 authentication
- Event creation
- Batch operations
- Calendar management

**Implementation**:
```dart
// Flutter
final calendarService = GoogleCalendarService();
await calendarService.addTasksToCalendar(tasks);
```

**Use Cases**:
- Learning path tasks → Calendar events
- Daily task scheduling
- Week-long task planning
- Automatic reminders

### 5. **Gmail API**

**Service**: Gmail  
**Package**: `googleapis/gmail`  
**Usage**: Sending job application emails

**Features**:
- OAuth 2.0 authentication
- Email composition
- Draft creation
- Email sending

**Implementation**:
```dart
// Flutter
final gmailService = GmailService();
await gmailService.sendJobApplicationEmail(
  recipient: 'hr@company.com',
  subject: 'Application for Software Engineer',
  body: generatedEmailBody
);
```

### 6. **Google Sign-In**

**Service**: Google Identity  
**Package**: `google_sign_in`  
**Usage**: Single Sign-On (SSO) for all Google services

**Features**:
- One-click authentication
- Access to Google services
- Profile information
- Token management

### 7. **Google Fonts**

**Service**: Google Fonts  
**Package**: `google_fonts`  
**Usage**: Typography in Flutter app

**Features**:
- Wide font selection
- Dynamic loading
- Custom typography
- Material Design integration

### 8. **Google Cloud Platform (GCP)**

**Services Used**:
- **Cloud Run**: Containerized backend deployment
- **Container Registry**: Docker image storage
- **Secret Manager**: Secure API key storage
- **Cloud Build**: CI/CD pipeline

**Deployment**:
```bash
# Deploy to Cloud Run
gcloud run deploy student-ai-backend \
    --image gcr.io/PROJECT_ID/student-ai-backend \
    --platform managed \
    --region us-central1
```

---

## ✨ Features

### 🎓 Learning Path Generator
- AI-powered personalized learning roadmaps
- Skill-based recommendations
- Progress tracking
- Google Calendar integration

### 💼 Internship Finder
- Real-time web scraping (Indeed, Skill India Digital)
- AI-powered relevance filtering
- Query optimization with Gemini
- Multi-source aggregation

### 📚 Book Learning System
- PDF upload and processing
- RAG-based concept extraction
- Interactive teaching engine
- Quiz generation
- Progress tracking

### 🎤 Mock Interview
- Voice-based interviews (STT + TTS)
- AI-generated questions
- Real-time feedback
- Resume-based customization

### 📄 Resume Optimizer
- AI-powered analysis
- ATS compatibility check
- Keyword optimization
- Job-specific tailoring

### 💼 Job Application Agent
- Job match analysis
- Email generation
- Tone customization
- Gmail integration

---

## 🛠️ Technology Stack

### Frontend
- **Flutter 3.x** (Dart) - Cross-platform mobile/web
- **Next.js 14+** (TypeScript) - Web dashboard
- **Provider** - State management
- **Material Design 3** - UI components

### Backend
- **FastAPI** - High-performance async API
- **Python 3.11+** - Backend language
- **Uvicorn** - ASGI server
- **Pydantic** - Data validation

### AI/ML
- **Google AI (Gemini 2.5 Flash)** - Primary LLM
- **Vertex AI** - Enterprise deployment
- **ChromaDB** - Vector database
- **Sentence Transformers** - Embeddings
- **RAG** - Retrieval-Augmented Generation

### Database & Storage
- **Firebase Firestore** - NoSQL database
- **ChromaDB** - Vector storage
- **Local Storage** - SharedPreferences (Flutter)

### DevOps
- **Docker** - Containerization
- **Google Cloud Run** - Serverless deployment
- **Cloud Build** - CI/CD
- **Secret Manager** - Secure configuration

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.x+)
- **Python** (3.11+)
- **Google Cloud Account** (for deployment)
- **Firebase Project**
- **Google AI API Key** (Gemini)

### 1. Clone the Repository

```bash
git clone https://github.com/shaileshms05/learnXAI.git
cd learnXAI
```

### 2. Backend Setup

```bash
cd ai-backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-books.txt
pip install -r requirements-interview.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your API keys

# Run the server
python main.py
```

**Required Environment Variables**:
```env
GOOGLE_API_KEY=your_google_api_key_here
FIREBASE_PROJECT_ID=your_firebase_project_id
PORT=8080
```

### 3. Flutter App Setup

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Configure Firebase
# Add your firebase_options.dart file

# Run the app
flutter run
```

### 4. Get API Keys

**Google AI (Gemini)**:
1. Visit: https://makersuite.google.com/app/apikey
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key

**Firebase**:
1. Visit: https://console.firebase.google.com/
2. Create a new project
3. Enable Authentication and Firestore
4. Download `firebase_options.dart`

---

## 📦 Deployment

### Backend Deployment (Google Cloud Run)

```bash
cd deployment

# Set your project ID
export GCP_PROJECT_ID=your-project-id

# Run deployment script
chmod +x deploy.sh
./deploy.sh
```

See [deployment/DEPLOYMENT.md](deployment/DEPLOYMENT.md) for detailed instructions.

### Docker Deployment

```bash
# Build Docker image
docker build -t student-ai-backend -f ai-backend/Dockerfile ai-backend/

# Run locally
docker run -p 8080:8080 \
  -e GOOGLE_API_KEY=your_key \
  -e FIREBASE_PROJECT_ID=your_project \
  student-ai-backend
```

---

## 📁 Project Structure

```
gdg-hackathon/
├── ai-backend/              # FastAPI backend
│   ├── main.py              # API server
│   ├── ai_client.py         # Unified AI client
│   ├── book_learning_system.py
│   ├── mock_interviewer.py
│   ├── resume_optimizer.py
│   └── requirements.txt
├── flutter_app/             # Flutter mobile/web app
│   ├── lib/
│   │   ├── screens/         # UI screens
│   │   ├── services/        # API clients
│   │   ├── providers/       # State management
│   │   └── models/          # Data models
│   └── pubspec.yaml
├── deployment/               # Deployment configs
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   └── deploy.sh
└── README.md
```

---

## 🎯 Key Concepts Demonstrated

### AI/ML Concepts
- **Large Language Models (LLMs)**: Gemini 2.5 Flash integration
- **RAG (Retrieval-Augmented Generation)**: Context-aware responses
- **Vector Embeddings**: Semantic search
- **Knowledge Graphs**: Concept relationships
- **Prompt Engineering**: Structured AI interactions

### Software Engineering
- **Microservices Architecture**: Separated frontend/backend
- **RESTful APIs**: Standard API design
- **Async Programming**: Non-blocking I/O
- **State Management**: Provider pattern
- **Error Handling**: Comprehensive error management

### DevOps
- **Containerization**: Docker
- **CI/CD**: Cloud Build
- **Serverless**: Cloud Run
- **Secret Management**: Secret Manager
- **Monitoring**: Cloud Logging

---

## 📊 API Endpoints

### Learning Path
- `POST /api/ai/learning-path` - Generate learning path
- `GET /api/learning-path/{user_id}` - Get user's learning path

### Internships
- `POST /api/internships/scrape` - Scrape internships
- `POST /api/internships/scrape/stream` - Stream scraping progress

### Resume
- `POST /api/resume/analyze` - Analyze resume
- `POST /api/resume/optimize` - Optimize resume

### Interview
- `POST /api/interview/start` - Start mock interview
- `POST /api/interview/answer` - Submit answer

### Books
- `POST /api/books/upload` - Upload book
- `POST /api/books/teach` - Get teaching content
- `POST /api/books/quiz` - Generate quiz

---

## 🤝 Contributing

This project was built for the GDG Hackathon. Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- **Google Developer Groups (GDG)** - Hackathon platform
- **Google AI** - Gemini API
- **Firebase** - Backend services
- **Flutter Team** - Cross-platform framework
- **FastAPI** - Modern Python framework

---

## 📞 Contact

- **GitHub**: [@shaileshms05](https://github.com/shaileshms05)
- **Project**: [learnXAI](https://github.com/shaileshms05/learnXAI)

---

<div align="center">

**Built with ❤️ for GDG Hackathon**

⭐ Star this repo if you find it helpful!

</div>

