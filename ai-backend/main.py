from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
import json
import asyncio
from openai import OpenAI
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables FIRST (before any imports that need them)
load_dotenv()

# Import training features
try:
    from knowledge_base import augment_prompt_with_knowledge, knowledge_base
    from training import data_collector
    RAG_ENABLED = True
    print("✅ RAG and Training features loaded")
except ImportError as e:
    RAG_ENABLED = False
    print(f"⚠️  RAG features not available. Run: pip install sentence-transformers chromadb pandas")
    print(f"   Error: {e}")

# Import unified AI client first (needed by other services)
try:
    from ai_client import UnifiedAIClient
    ai_client = UnifiedAIClient()
    client = ai_client  # For backward compatibility
    MODEL = ai_client.model_name
    print(f"✅ AI Client initialized with provider: {ai_client.provider}, model: {MODEL}")
except Exception as e:
    print(f"❌ Failed to initialize AI client: {e}")
    raise

# Import book learning system (needs AI client - initialized after AI client)
try:
    from book_learning_system import BookLearningSystem, BOOKS_ENABLED
    if BOOKS_ENABLED:
        # Pass the unified AI client to book system
        book_system = BookLearningSystem(ai_client=ai_client)
        print("✅ Book Learning System loaded")
    else:
        book_system = None
        print("⚠️  Book Learning System not available. Run: pip install -r requirements-books.txt")
except ImportError as e:
    BOOKS_ENABLED = False
    book_system = None
    print(f"⚠️  Book Learning System not available: {e}")
except Exception as e:
    BOOKS_ENABLED = False
    book_system = None
    print(f"⚠️  Book Learning System initialization failed: {e}")

# Import mock interview system (uses unified AI client)
try:
    from mock_interviewer import MockInterviewer
    interview_system = MockInterviewer(ai_client)
    INTERVIEW_ENABLED = True
    print("✅ Mock Interview System loaded")
except ImportError as e:
    INTERVIEW_ENABLED = False
    interview_system = None
    print(f"⚠️  Mock Interview System not available: {e}")
    print("   Run: pip install -r requirements-interview.txt")

# Import job application agent (uses unified AI client)
try:
    from job_application_agent import JobApplicationAgent, JOB_AGENT_ENABLED
    if JOB_AGENT_ENABLED:
        job_agent = JobApplicationAgent(ai_client)
        print("✅ Job Application Agent loaded")
    else:
        job_agent = None
        print("⚠️  Job Application Agent not available")
except ImportError as e:
    JOB_AGENT_ENABLED = False
    job_agent = None
    print(f"⚠️  Job Application Agent not available: {e}")

# Import resume optimizer (uses unified AI client)
try:
    from resume_optimizer import ResumeOptimizer, RESUME_OPTIMIZER_ENABLED
    from resume_analyzer import ResumeAnalyzer
    if RESUME_OPTIMIZER_ENABLED:
        resume_optimizer = ResumeOptimizer(ai_client)
        if 'resume_analyzer' not in locals():
            resume_analyzer = ResumeAnalyzer()
        print("✅ Resume Optimizer loaded")
    else:
        resume_optimizer = None
        print("⚠️  Resume Optimizer not available")
except ImportError as e:
    RESUME_OPTIMIZER_ENABLED = False
    resume_optimizer = None
    print(f"⚠️  Resume Optimizer not available: {e}")

# Initialize FastAPI
app = FastAPI(title="Student AI Platform API", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic Models
class LearningPathRequest(BaseModel):
    interests: List[str]
    skills: List[str]
    careerGoal: str
    educationLevel: str
    timeCommitment: str

class InternshipRequest(BaseModel):
    skills: List[str]
    interests: List[str]
    location: str
    experienceLevel: str

class ChatMessage(BaseModel):
    message: str
    context: Optional[dict] = None

class LearningPathResponse(BaseModel):
    title: str
    description: str
    totalDuration: str
    difficultyLevel: str
    phases: List[dict]
    careerOutcomes: dict
    skillsAcquired: List[str]
    prerequisites: List[str]
    dailyTimeCommitment: str
    successStories: List[dict]
    communityResources: List[dict]
    certifications: List[dict]
    nextSteps: List[str]

class InternshipResponse(BaseModel):
    opportunities: List[dict]

class ChatResponse(BaseModel):
    message: str
    suggestions: Optional[List[str]] = None


# Health check endpoint
@app.get("/")
async def root():
    return {
        "message": "Student AI Platform API",
        "status": "running",
        "version": "1.0.0",
        "rag_enabled": RAG_ENABLED,
        "training_enabled": RAG_ENABLED
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "rag_enabled": RAG_ENABLED
    }


# AI Learning Path Generator
@app.post("/api/ai/learning-path", response_model=LearningPathResponse)
async def generate_learning_path(request: LearningPathRequest):
    """
    Generate a personalized learning path based on student profile (with RAG enhancement)
    """
    try:
        # Build query for RAG search
        query = f"Learning path for {request.careerGoal} with skills in {', '.join(request.skills)}"
        
        prompt = f"""
You are an expert educational advisor. Generate a comprehensive, personalized learning path for a student with the following profile:

**Student Profile:**
- Interests: {', '.join(request.interests)}
- Current Skills: {', '.join(request.skills)}
- Career Goal: {request.careerGoal}
- Education Level: {request.educationLevel}
- Time Commitment: {request.timeCommitment}

**Instructions:**
Create a comprehensive, actionable learning path in the following JSON format:
{{
    "title": "A compelling, specific title for the learning path",
    "description": "A detailed 2-3 sentence overview of the learning journey and career outcome",
    "totalDuration": "Total estimated time (e.g., 6-8 months)",
    "difficultyLevel": "beginner/intermediate/advanced",
    "phases": [
        {{
            "phaseNumber": 1,
            "title": "Phase name (e.g., Foundation Building)",
            "duration": "2-3 months",
            "description": "What the learner will achieve in this phase",
            "topics": [
                {{
                    "name": "Specific topic name",
                    "subtopics": ["subtopic1", "subtopic2", "subtopic3"],
                    "estimatedHours": 20,
                    "difficulty": "beginner/intermediate/advanced"
                }}
            ],
            "learningResources": [
                {{
                    "title": "Resource name",
                    "type": "course/book/tutorial/documentation",
                    "provider": "Coursera/Udemy/YouTube/Official Docs",
                    "url": "https://example.com/resource",
                    "duration": "4 weeks",
                    "cost": "free/paid",
                    "description": "Why this resource is recommended"
                }}
            ],
            "practiceProjects": [
                {{
                    "title": "Project name",
                    "description": "What you'll build and learn",
                    "difficulty": "beginner/intermediate/advanced",
                    "estimatedHours": 10,
                    "skills": ["skill1", "skill2"],
                    "githubExample": "Optional GitHub repo reference"
                }}
            ],
            "weekByWeekPlan": [
                {{
                    "week": 1,
                    "focus": "What to learn this week",
                    "tasks": ["task1", "task2", "task3"],
                    "deliverable": "What you should complete"
                }}
            ],
            "assessmentCriteria": [
                "How to know you've mastered this phase"
            ]
        }}
    ],
    "careerOutcomes": {{
        "jobTitles": ["Potential job titles you'll be qualified for"],
        "averageSalary": "Salary range in your region",
        "marketDemand": "high/medium/low",
        "requiredYearsExperience": "0-2 years"
    }},
    "skillsAcquired": ["comprehensive list of all skills"],
    "prerequisites": ["what you should know before starting"],
    "dailyTimeCommitment": "Recommended hours per day",
    "successStories": [
        {{
            "achievement": "Example success case",
            "timeline": "How long it took"
        }}
    ],
    "communityResources": [
        {{
            "name": "Discord/Reddit/Forum name",
            "url": "https://community.example.com",
            "description": "Why join this community"
        }}
    ],
    "certifications": [
        {{
            "name": "Certification name",
            "provider": "Certification provider",
            "cost": "free/paid",
            "value": "Why this certification matters"
        }}
    ],
    "nextSteps": [
        "What to do after completing this path"
    ]
}}

CRITICAL REQUIREMENTS:
1. Make the path HIGHLY PRACTICAL with real-world applications
2. Include SPECIFIC, ACTIONABLE resources with actual URLs when possible
3. Break down learning into WEEKLY tasks (not just phases)
4. Provide MEASURABLE milestones (e.g., "Build a todo app with auth")
5. Include FREE resources primarily (mark paid ones clearly)
6. Add REALISTIC time estimates based on industry standards
7. Suggest HANDS-ON projects that can be added to portfolio
8. Include community support options
9. Mention relevant certifications
10. Focus on skills that are IN-DEMAND in current job market

Return ONLY the JSON, no additional text.
"""

        # Enhance with RAG if available
        if RAG_ENABLED:
            prompt = augment_prompt_with_knowledge(query, prompt)

        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are an expert career counselor and educational pathway designer with deep industry knowledge. Create detailed, actionable learning paths. Always respond with valid JSON only."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=4000  # Increased for detailed response
        )
        
        result_text = response.choices[0].message.content.strip()
        
        # Remove markdown code blocks if present
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        
        result_text = result_text.strip()
        
        # Parse the JSON response
        learning_path = json.loads(result_text)
        
        # Log interaction for training if RAG enabled
        if RAG_ENABLED:
            data_collector.log_interaction(
                user_query=query,
                ai_response=json.dumps(learning_path),
                feature='learning_path',
                metadata={'career_goal': request.careerGoal, 'education_level': request.educationLevel}
            )
        
        return LearningPathResponse(**learning_path)
    
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse AI response: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating learning path: {str(e)}")


# AI Internship/Opportunity Recommendations
@app.post("/api/ai/internships", response_model=InternshipResponse)
async def recommend_internships(request: InternshipRequest):
    """
    Generate personalized internship and opportunity recommendations (with RAG enhancement)
    """
    try:
        # Build query for RAG search
        query = f"Internship opportunities for {', '.join(request.skills)} skills in {request.location}"
        
        prompt = f"""
You are a career counselor specializing in student internships and opportunities. Recommend opportunities for a student with this profile:

**Student Profile:**
- Skills: {', '.join(request.skills)}
- Interests: {', '.join(request.interests)}
- Preferred Location: {request.location}
- Experience Level: {request.experienceLevel}

**Instructions:**
Generate a list of 5-7 relevant internship opportunities in the following JSON format:
{{
    "opportunities": [
        {{
            "title": "Internship/Opportunity Title",
            "company": "Company or Organization Name",
            "type": "Type (e.g., Internship, Research Position, Volunteer)",
            "location": "Location (Remote/City)",
            "duration": "Duration (e.g., 3 months, Summer)",
            "description": "2-3 sentences describing the opportunity",
            "requiredSkills": ["skill1", "skill2"],
            "benefits": ["benefit1", "benefit2"],
            "applicationTips": "Brief advice for applying",
            "matchScore": 85
        }}
    ]
}}

Focus on:
1. Real-world, relevant opportunities
2. Mix of in-person and remote options
3. Various company sizes (startups to large companies)
4. Include open-source, research, and industry positions
5. Practical application tips

Return ONLY the JSON, no additional text.
"""

        # Enhance with RAG if available
        if RAG_ENABLED:
            prompt = augment_prompt_with_knowledge(query, prompt)

        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a career counselor specializing in internships. Always respond with valid JSON only."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=2000
        )
        
        result_text = response.choices[0].message.content.strip()
        
        # Remove markdown code blocks if present
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        
        result_text = result_text.strip()
        
        # Parse the JSON response
        opportunities = json.loads(result_text)
        
        # Log interaction for training if RAG enabled
        if RAG_ENABLED:
            data_collector.log_interaction(
                user_query=query,
                ai_response=json.dumps(opportunities),
                feature='internships',
                metadata={'location': request.location, 'experience_level': request.experienceLevel}
            )
        
        return InternshipResponse(**opportunities)
    
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse AI response: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error recommending internships: {str(e)}")


# Real-time Internship Scraping
class ScrapeInternshipRequest(BaseModel):
    query: str
    location: Optional[str] = ""
    max_results: Optional[int] = 20
    sources: Optional[List[str]] = []

@app.get("/api/internships/scrape/status")
async def scrape_status():
    """Check if scraping endpoint is available"""
    import sys
    import os
    scraper_dir = os.path.join(os.path.dirname(__file__), '..', 'mcp-internship-scraper')
    scraper_path = os.path.join(scraper_dir, 'scraper.py')
    
    return {
        "available": os.path.exists(scraper_path),
        "scraper_path": scraper_path,
        "scraper_dir": scraper_dir,
        "message": "Scraping endpoint is available" if os.path.exists(scraper_path) else "Scraper not found"
    }

@app.get("/api/internships/scrape/test")
async def test_scrape():
    """Test scraping endpoint with a simple query"""
    try:
        import sys
        import os
        scraper_dir = os.path.join(os.path.dirname(__file__), '..', 'mcp-internship-scraper')
        scraper_path = os.path.join(scraper_dir, 'scraper.py')
        
        if not os.path.exists(scraper_path):
            return {"error": "Scraper not found", "path": scraper_path}
        
        parent_dir = os.path.dirname(scraper_path)
        if parent_dir not in sys.path:
            sys.path.insert(0, parent_dir)
        
        from scraper import InternshipScraper
        
        scraper = InternshipScraper()
        results = scraper.scrape_indeed("software engineer", "Remote", 5)
        
        return {
            "success": True,
            "results_count": len(results),
            "results": results[:3],  # Return first 3 for debugging
            "message": f"Found {len(results)} internships"
        }
    except Exception as e:
        import traceback
        return {
            "error": str(e),
            "traceback": traceback.format_exc()
        }

async def process_query_with_ai(query: str, location: str = "") -> dict:
    """
    Use AI (Google AI or Cerebras) to process and optimize the search query for internship scraping.
    Extracts optimized search terms, location normalization, and search parameters.
    """
    try:
        prompt = f"""
You are an expert at optimizing job search queries for internship opportunities. Process the following search request and extract the best search parameters.

**User Query:** {query}
**User Location:** {location if location else "Not specified"}

**Your Task:**
1. Extract the core job title/role keywords (e.g., "software engineer", "data scientist", "web developer")
2. Normalize and format the location (e.g., "bangalore" -> "Bangalore, Karnataka", "remote" -> "Remote")
3. Determine if "intern" or "internship" should be added to the query
4. Suggest the best search query string for job boards

**Output Format (JSON only):**
{{
    "optimized_query": "optimized search query string",
    "location": "normalized location string",
    "keywords": ["keyword1", "keyword2"],
    "should_add_intern": true/false,
    "search_strategy": "brief explanation"
}}

**Guidelines:**
- Keep the query concise but specific (2-4 key terms)
- DO NOT include location in the query string - location is handled separately
- For Indian cities, use full format: "City, State" (e.g., "Bengaluru, Karnataka") in the location field only
- For remote, use "Remote" (capitalized) in the location field only
- Only add "intern" if not already present in the query
- Focus on the most important skills/role terms (e.g., "software engineer", "data scientist")
- Example: Query "software engineer" + Location "bangalore" → optimized_query: "software engineer intern", location: "Bengaluru, Karnataka"

Return ONLY valid JSON, no additional text.
"""
        
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a job search query optimizer. Always respond with valid JSON only."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,  # Lower temperature for more consistent results
            max_tokens=500
        )
        
        result_text = response.choices[0].message.content.strip()
        
        # Remove markdown code blocks if present
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        
        result_text = result_text.strip()
        
        # Parse the JSON response
        processed = json.loads(result_text)
        
        provider_name = ai_client.provider.upper() if hasattr(ai_client, 'provider') else "AI"
        print(f"🤖 {provider_name} processed query:")
        print(f"   Original: '{query}' in '{location}'")
        print(f"   Optimized: '{processed.get('optimized_query', query)}' in '{processed.get('location', location)}'")
        print(f"   Strategy: {processed.get('search_strategy', 'N/A')}")
        
        return processed
        
    except json.JSONDecodeError as e:
        print(f"⚠️  Failed to parse Cerebras response, using original query: {e}")
        # Fallback to original query
        return {
            "optimized_query": query,
            "location": location,
            "keywords": query.split(),
            "should_add_intern": "intern" not in query.lower() and "internship" not in query.lower(),
            "search_strategy": "Using original query (AI processing failed)"
        }
    except Exception as e:
        print(f"⚠️  Error processing query with Cerebras: {e}")
        # Fallback to original query
        return {
            "optimized_query": query,
            "location": location,
            "keywords": query.split(),
            "should_add_intern": "intern" not in query.lower() and "internship" not in query.lower(),
            "search_strategy": "Using original query (AI processing failed)"
        }

@app.post("/api/internships/scrape")
async def scrape_internships(request: ScrapeInternshipRequest):
    """
    Scrape real-time internship opportunities from job boards.
    Uses Cerebras to optimize the query before scraping.
    """
    print(f"🔍 Scrape request received: query={request.query}, location={request.location}, max_results={request.max_results}")
    try:
        # Step 1: Process query with AI to optimize search parameters
        processed = await process_query_with_ai(request.query, request.location or "")
        
        # Extract optimized parameters
        optimized_query = processed.get("optimized_query", request.query)
        optimized_location = processed.get("location", request.location or "")
        
        print(f"📊 Using optimized query: '{optimized_query}' in '{optimized_location}'")
        
        # Import scraper (use standalone scraper.py, not server.py which requires MCP)
        import sys
        import os
        scraper_dir = os.path.join(os.path.dirname(__file__), '..', 'mcp-internship-scraper')
        scraper_path = os.path.join(scraper_dir, 'scraper.py')
        
        print(f"📁 Looking for scraper at: {scraper_path}")
        print(f"📁 Scraper exists: {os.path.exists(scraper_path)}")
        
        if os.path.exists(scraper_path):
            # Add parent directory to path to allow import
            parent_dir = os.path.dirname(scraper_path)
            if parent_dir not in sys.path:
                sys.path.insert(0, parent_dir)
            
            print(f"📦 Importing InternshipScraper from {parent_dir}")
            from scraper import InternshipScraper
            
            scraper = InternshipScraper()
            
            # Determine which sources to scrape (default to all sources including Skill India Digital)
            # If sources is not provided or is empty, use all sources
            if not request.sources or len(request.sources) == 0:
                sources = ['indeed', 'linkedin', 'glassdoor', 'internships.com', 'skill_india']
            else:
                sources = request.sources
                # Always include skill_india if not explicitly excluded
                if 'skill_india' not in sources and 'skillindiadigital' not in sources:
                    sources = list(sources) + ['skill_india']  # Add skill_india to the list
            all_internships = []
            
            max_per_source = max(10, request.max_results // max(len(sources), 1)) if sources else request.max_results
            
            print(f"🔍 Scraping from sources: {sources}")
            print(f"📊 Max per source: {max_per_source}")
            print(f"📝 Original Query: '{request.query}', Location: '{request.location}'")
            print(f"📝 Optimized Query: '{optimized_query}', Location: '{optimized_location}'")
            
            if 'indeed' in sources:
                print("🌐 Scraping Indeed...")
                indeed_results = scraper.scrape_indeed(optimized_query, optimized_location, max_per_source)
                print(f"✅ Indeed: {len(indeed_results)} results")
                if indeed_results:
                    print(f"   Sample: {indeed_results[0].get('title', 'N/A')} at {indeed_results[0].get('company', 'N/A')}")
                all_internships.extend(indeed_results)
            
            if 'linkedin' in sources:
                print("🌐 Scraping LinkedIn...")
                linkedin_results = scraper.scrape_linkedin(optimized_query, optimized_location, max_per_source)
                print(f"✅ LinkedIn: {len(linkedin_results)} results")
                all_internships.extend(linkedin_results)
            
            if 'glassdoor' in sources:
                print("🌐 Scraping Glassdoor...")
                glassdoor_results = scraper.scrape_glassdoor(optimized_query, optimized_location, max_per_source)
                print(f"✅ Glassdoor: {len(glassdoor_results)} results")
                all_internships.extend(glassdoor_results)
            
            if 'internships.com' in sources:
                print("🌐 Scraping Internships.com...")
                internships_com_results = scraper.scrape_internships_com(optimized_query, optimized_location, max_per_source)
                print(f"✅ Internships.com: {len(internships_com_results)} results")
                all_internships.extend(internships_com_results)
            
            if 'skill_india' in sources or 'skillindiadigital' in sources:
                print("🌐 Scraping Skill India Digital...")
                skill_india_results = scraper.scrape_skill_india(optimized_query, optimized_location, max_per_source)
                print(f"✅ Skill India Digital: {len(skill_india_results)} results")
                if skill_india_results:
                    print(f"   Sample: {skill_india_results[0].get('title', 'N/A')} at {skill_india_results[0].get('company', 'N/A')}")
                all_internships.extend(skill_india_results)
            
            print(f"📊 Total scraped: {len(all_internships)} internships")
            
            # Debug: Print first few results
            if all_internships:
                print("📋 Sample results:")
                for i, job in enumerate(all_internships[:3]):
                    print(f"   {i+1}. {job.get('title', 'N/A')} - {job.get('company', 'N/A')} ({job.get('source', 'N/A')})")
            
            # Only use fallback if absolutely no results AND user explicitly wants it
            # For now, return empty list if scraping fails - let user know it's not working
            # if len(all_internships) == 0:
            #     print("⚠️  No results from scraping, generating sample internships...")
            #     all_internships = scraper.generate_sample_internships(
            #         request.query, 
            #         request.location, 
            #         request.max_results
            #     )
            #     print(f"📝 Generated {len(all_internships)} sample internships")
            
            # Remove duplicates
            seen = set()
            unique_internships = []
            for internship in all_internships:
                key = (internship['title'].lower(), internship['company'].lower())
                if key not in seen:
                    seen.add(key)
                    # Format for frontend compatibility
                    formatted = {
                        'title': internship['title'],
                        'company': internship['company'],
                        'description': internship.get('description', f"Internship opportunity for {request.query} at {internship['company']}"),
                        'location': internship['location'],
                        'type': 'Internship',
                        'duration': '3-6 months',
                        'requiredSkills': [request.query] if request.query else [],
                        'benefits': ['Mentorship', 'Networking', 'Real-world experience'],
                        'applicationTips': f"Apply via {internship['source']} or company website",
                        'matchScore': 80 if internship['source'] != 'Sample' else 70,
                        'url': internship.get('url', ''),
                        'source': internship['source'],
                        'scraped_at': internship.get('scraped_at', datetime.now().isoformat())
                    }
                    unique_internships.append(formatted)
            
            print(f"✅ Returning {len(unique_internships)} unique internships")
            
            return {
                'success': True,
                'total_results': len(unique_internships),
                'opportunities': unique_internships,
                'scraped_sources': sources,
                'has_fallback': len([i for i in unique_internships if i.get('source') == 'Sample']) > 0,
                'query_optimization': {
                    'original_query': request.query,
                    'optimized_query': optimized_query,
                    'original_location': request.location or "",
                    'optimized_location': optimized_location,
                    'strategy': processed.get('search_strategy', 'N/A')
                }
            }
        else:
            print(f"❌ Scraper not found at: {scraper_path}")
            raise HTTPException(
                status_code=503,
                detail=f"Internship scraper not available. Scraper file not found at: {scraper_path}. Please ensure mcp-internship-scraper/server.py exists."
            )
    
    except ImportError as e:
        print(f"❌ Import error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=503,
            detail=f"Scraper dependencies not available: {str(e)}. Install with: pip install requests beautifulsoup4 lxml mcp"
        )
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        print(f"❌ Error scraping internships: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error scraping internships: {str(e)}")


@app.post("/api/internships/scrape/stream")
async def scrape_internships_stream(request: ScrapeInternshipRequest):
    """
    Stream scraping progress with Server-Sent Events (SSE) for real-time UI updates
    """
    async def generate():
        try:
            # Send initial status
            yield f"data: {json.dumps({'type': 'status', 'message': 'Starting internship search...', 'progress': 0})}\n\n"
            await asyncio.sleep(0.1)
            
            # Step 1: Process query with AI (Google AI or Cerebras)
            yield f"data: {json.dumps({'type': 'status', 'message': 'Optimizing search query with AI...', 'progress': 10})}\n\n"
            processed = await process_query_with_ai(request.query, request.location or "")
            optimized_query = processed.get("optimized_query", request.query)
            optimized_location = processed.get("location", request.location or "")
            
            yield f"data: {json.dumps({'type': 'query_optimized', 'original': request.query, 'optimized': optimized_query, 'progress': 20})}\n\n"
            await asyncio.sleep(0.1)
            
            # Import scraper
            import sys
            import os
            scraper_dir = os.path.join(os.path.dirname(__file__), '..', 'mcp-internship-scraper')
            scraper_path = os.path.join(scraper_dir, 'scraper.py')
            
            if not os.path.exists(scraper_path):
                yield f"data: {json.dumps({'type': 'error', 'message': 'Scraper not found'})}\n\n"
                return
            
            parent_dir = os.path.dirname(scraper_path)
            if parent_dir not in sys.path:
                sys.path.insert(0, parent_dir)
            
            from scraper import InternshipScraper
            scraper = InternshipScraper()
            
            # Determine sources
            if not request.sources or len(request.sources) == 0:
                sources = ['indeed', 'linkedin', 'glassdoor', 'internships.com', 'skill_india']
            else:
                sources = request.sources
                if 'skill_india' not in sources and 'skillindiadigital' not in sources:
                    sources = list(sources) + ['skill_india']
            
            max_per_source = max(10, request.max_results // max(len(sources), 1)) if sources else request.max_results
            all_internships = []
            
            total_sources = len(sources)
            progress_per_source = 70 / total_sources  # 70% for scraping, 20% already used, 10% for final processing
            
            # Scrape each source with progress updates
            for idx, source in enumerate(sources):
                current_progress = 20 + (idx * progress_per_source)
                source_name = source.replace('_', ' ').title()
                
                yield f"data: {json.dumps({'type': 'scraping', 'source': source, 'source_name': source_name, 'message': f'Scraping {source_name}...', 'progress': int(current_progress)})}\n\n"
                
                try:
                    if source == 'indeed':
                        results = scraper.scrape_indeed(optimized_query, optimized_location, max_per_source)
                    elif source == 'linkedin':
                        results = scraper.scrape_linkedin(optimized_query, optimized_location, max_per_source)
                    elif source == 'glassdoor':
                        results = scraper.scrape_glassdoor(optimized_query, optimized_location, max_per_source)
                    elif source == 'internships.com':
                        results = scraper.scrape_internships_com(optimized_query, optimized_location, max_per_source)
                    elif source in ['skill_india', 'skillindiadigital']:
                        results = scraper.scrape_skill_india(optimized_query, optimized_location, max_per_source)
                    else:
                        results = []
                    
                    all_internships.extend(results)
                    yield f"data: {json.dumps({'type': 'source_complete', 'source': source, 'source_name': source_name, 'count': len(results), 'progress': int(current_progress + progress_per_source)})}\n\n"
                except Exception as e:
                    yield f"data: {json.dumps({'type': 'source_error', 'source': source, 'source_name': source_name, 'error': str(e), 'progress': int(current_progress + progress_per_source)})}\n\n"
                
                await asyncio.sleep(0.1)
            
            # Process results
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing and deduplicating results...', 'progress': 90})}\n\n"
            
            # Remove duplicates
            seen = set()
            unique_internships = []
            for internship in all_internships:
                key = (internship['title'].lower(), internship['company'].lower())
                if key not in seen:
                    seen.add(key)
                    formatted = {
                        'title': internship['title'],
                        'company': internship['company'],
                        'description': internship.get('description', f"Internship opportunity for {request.query} at {internship['company']}"),
                        'location': internship['location'],
                        'type': 'Internship',
                        'duration': '3-6 months',
                        'requiredSkills': [request.query] if request.query else [],
                        'benefits': ['Mentorship', 'Networking', 'Real-world experience'],
                        'applicationTips': f"Apply via {internship['source']} or company website",
                        'matchScore': 80 if internship['source'] != 'Sample' else 70,
                        'url': internship.get('url', ''),
                        'source': internship['source'],
                        'scraped_at': internship.get('scraped_at', datetime.now().isoformat())
                    }
                    unique_internships.append(formatted)
            
            # Send final results
            yield f"data: {json.dumps({'type': 'complete', 'total': len(unique_internships), 'opportunities': unique_internships, 'progress': 100})}\n\n"
            
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
    
    return StreamingResponse(generate(), media_type="text/event-stream")


# AI Career Guidance Chatbot
@app.post("/api/ai/chat", response_model=ChatResponse)
async def chat(request: ChatMessage):
    """
    AI-powered career guidance chatbot (with RAG enhancement)
    """
    try:
        # Build context if provided
        context_str = ""
        if request.context:
            context_str = f"""
**Student Context:**
- Education Level: {request.context.get('educationLevel', 'Not specified')}
- Career Goal: {request.context.get('careerGoal', 'Not specified')}
- Current Skills: {', '.join(request.context.get('skills', []))}
- Interests: {', '.join(request.context.get('interests', []))}
"""

        prompt = f"""
You are an expert career counselor and mentor for students. Provide helpful, encouraging, and practical advice.

{context_str}

**Student Question:**
{request.message}

**Instructions:**
1. Provide a clear, supportive response (2-3 paragraphs)
2. Include specific, actionable advice
3. Be encouraging and motivating
4. If relevant, suggest 2-3 concrete next steps

Keep your response conversational and supportive. Format your response as plain text (not JSON).
"""

        # Enhance with RAG if available
        if RAG_ENABLED:
            prompt = augment_prompt_with_knowledge(request.message, prompt)

        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are an expert career counselor and mentor for students. Provide helpful, encouraging advice."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.8,
            max_tokens=1000
        )
        
        result_text = response.choices[0].message.content.strip()
        
        # Generate follow-up suggestions
        suggestions_prompt = f"""
Based on this career guidance conversation:
Question: {request.message}
Answer: {result_text[:200]}...

Suggest 3 brief follow-up questions the student might ask (each max 10 words).
Return as a JSON array: ["question1", "question2", "question3"]
"""
        
        suggestions_response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "Generate follow-up questions. Return only a JSON array."},
                {"role": "user", "content": suggestions_prompt}
            ],
            temperature=0.7,
            max_tokens=200
        )
        
        suggestions_text = suggestions_response.choices[0].message.content.strip()
        
        # Parse suggestions
        if suggestions_text.startswith("```json"):
            suggestions_text = suggestions_text[7:]
        if suggestions_text.startswith("```"):
            suggestions_text = suggestions_text[3:]
        if suggestions_text.endswith("```"):
            suggestions_text = suggestions_text[:-3]
        
        suggestions_text = suggestions_text.strip()
        
        suggestions = json.loads(suggestions_text)
        
        # Log interaction for training if RAG enabled
        if RAG_ENABLED:
            data_collector.log_interaction(
                user_query=request.message,
                ai_response=result_text,
                feature='chat',
                metadata=request.context if request.context else {}
            )
        
        return ChatResponse(message=result_text, suggestions=suggestions)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in chat: {str(e)}")


# ============================================================================
# BOOK LEARNING SYSTEM ENDPOINTS ("Upload → Learn → Master")
# ============================================================================

class BookUploadRequest(BaseModel):
    file_path: str
    file_type: str  # pdf, epub, docx
    user_id: str

class TeachingRequest(BaseModel):
    book_id: str
    chapter_num: int
    style: str = "simple"  # simple, code-first, math-heavy, interview

class UnderstandingCheckRequest(BaseModel):
    book_id: str
    concept_id: str
    question: str
    student_answer: str
    user_id: str

class QuizRequest(BaseModel):
    book_id: str
    chapter_num: int

class MasteryRequest(BaseModel):
    user_id: str
    book_id: str

class BookChatRequest(BaseModel):
    book_id: str
    question: str


@app.post("/api/books/upload")
async def upload_book(request: BookUploadRequest):
    """
    Upload and process a book
    
    This endpoint:
    1. Processes PDF/EPUB/DOCX
    2. Extracts chapters and sections
    3. Extracts concepts using AI
    4. Builds knowledge graph
    5. Initializes learning progress
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(
            status_code=503, 
            detail="Book learning system not available. Install requirements-books.txt"
        )
    
    try:
        result = book_system.upload_book(
            file_path=request.file_path,
            file_type=request.file_type,
            user_id=request.user_id
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Upload failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading book: {str(e)}")


@app.post("/api/books/teach")
async def start_teaching(request: TeachingRequest):
    """
    Start teaching a chapter
    
    Returns:
    - Adaptive explanation based on style
    - Concrete example
    - Understanding check question
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(status_code=503, detail="Book learning system not available")
    
    try:
        result = book_system.start_teaching(
            book_id=request.book_id,
            chapter_num=request.chapter_num,
            style=request.style
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Teaching failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error teaching: {str(e)}")


@app.post("/api/books/check-understanding")
async def check_understanding(request: UnderstandingCheckRequest):
    """
    Evaluate student's answer to understanding check
    
    Returns:
    - Score (0-100)
    - Detailed feedback
    - Missing concepts
    - Misconceptions
    - Next action (continue/review)
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(status_code=503, detail="Book learning system not available")
    
    try:
        result = book_system.check_understanding(
            book_id=request.book_id,
            concept_id=request.concept_id,
            question=request.question,
            student_answer=request.student_answer,
            user_id=request.user_id
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Evaluation failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error evaluating: {str(e)}")


@app.post("/api/books/generate-quiz")
async def generate_quiz(request: QuizRequest):
    """
    Generate quiz for a chapter
    
    Returns:
    - Mix of MCQ, short answer, and explanation questions
    - Derived from book content
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(status_code=503, detail="Book learning system not available")
    
    try:
        result = book_system.generate_chapter_quiz(
            book_id=request.book_id,
            chapter_num=request.chapter_num
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Quiz generation failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating quiz: {str(e)}")


@app.post("/api/books/mastery-dashboard")
async def get_mastery_dashboard(request: MasteryRequest):
    """
    Get mastery dashboard
    
    Returns:
    - Overall mastery percentage
    - Per-chapter progress
    - Concept mastery breakdown
    - Visual progress bars data
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(status_code=503, detail="Book learning system not available")
    
    try:
        result = book_system.get_mastery_dashboard(
            user_id=request.user_id,
            book_id=request.book_id
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Dashboard failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting dashboard: {str(e)}")


@app.post("/api/books/chat")
async def chat_with_book(request: BookChatRequest):
    """
    Chat with the book using RAG
    
    Features:
    - Answers using ONLY book content
    - Provides page/chapter references
    - Suggests related concepts
    
    Example: "Explain backpropagation using THIS book only"
    """
    if not BOOKS_ENABLED or not book_system:
        raise HTTPException(status_code=503, detail="Book learning system not available")
    
    try:
        result = book_system.chat_with_book(
            book_id=request.book_id,
            question=request.question
        )
        
        if result.get('success'):
            return result
        else:
            raise HTTPException(status_code=400, detail=result.get('error', 'Chat failed'))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in book chat: {str(e)}")


@app.get("/api/books/status")
async def book_system_status():
    """Check if book learning system is available"""
    return {
        "available": BOOKS_ENABLED and book_system is not None,
        "features": [
            "PDF/EPUB/DOCX processing",
            "Concept extraction",
            "Knowledge graphs",
            "Adaptive teaching",
            "Understanding checks",
            "Quiz generation",
            "Mastery tracking",
            "Book-specific chat (RAG)"
        ] if BOOKS_ENABLED else [],
        "message": "Book Learning System ready" if BOOKS_ENABLED else "Install requirements-books.txt to enable"
    }


# ============================================================================
# MOCK INTERVIEW ENDPOINTS
# ============================================================================

class InterviewStartRequest(BaseModel):
    resume_path: Optional[str] = None  # For mobile/file paths
    resume_type: Optional[str] = "pdf"  # pdf, docx
    user_id: str
    interview_type: str = "technical"  # technical, behavioral, hr
    difficulty: str = "medium"  # easy, medium, hard
    resume_data: Optional[str] = None  # Base64 encoded file data for web uploads


class InterviewAnswerRequest(BaseModel):
    session_id: str
    answer: str


@app.post("/api/interview/start")
async def start_interview(request: InterviewStartRequest):
    """
    🎤 Start a Mock Interview Session
    
    Upload your resume and start an AI-powered mock interview with:
    - Voice-based questions (AI speaks the questions)
    - Resume-specific questions based on your skills/experience
    - Real-time evaluation and feedback
    - Multiple interview types (technical, behavioral, HR)
    
    Returns:
    - Session ID
    - First question (text + audio URL)
    - Resume summary
    """
    if not INTERVIEW_ENABLED or not interview_system:
        raise HTTPException(status_code=503, detail="Interview system not available. Install requirements-interview.txt")
    
    try:
        # Handle web uploads (base64 data) vs mobile (file path) - same approach as resume optimizer
        resume_path = request.resume_path
        resume_type = request.resume_type or "pdf"
        temp_file_created = False
        
        if request.resume_data:
            # Web upload: decode base64 and save to temp file (same as resume optimizer approach)
            import base64
            import tempfile
            
            try:
                # Decode base64 data
                file_bytes = base64.b64decode(request.resume_data)
                
                # Create temp file with proper extension
                extension = resume_type if resume_type.startswith('.') else f'.{resume_type}'
                with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as tmp_file:
                    tmp_file.write(file_bytes)
                    resume_path = tmp_file.name
                    temp_file_created = True
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Error processing uploaded file: {str(e)}")
        
        if not resume_path:
            raise HTTPException(status_code=400, detail="Either resume_path or resume_data must be provided")
        
        # Use the same ResumeAnalyzer.parse_resume method as resume optimizer
        result = interview_system.start_interview(
            resume_path=resume_path,
            resume_type=resume_type,
            user_id=request.user_id,
            interview_type=request.interview_type,
            difficulty=request.difficulty
        )
        
        # Clean up temp file if it was created from base64 data
        if temp_file_created and resume_path and os.path.exists(resume_path):
            try:
                os.unlink(resume_path)
            except:
                pass  # Ignore cleanup errors
        
        return result
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error starting interview: {str(e)}")


@app.post("/api/interview/answer")
async def submit_answer(request: InterviewAnswerRequest):
    """
    📝 Submit Answer to Interview Question
    
    Submit your answer to the current question and receive:
    - Instant AI feedback on your answer
    - Score (0-10)
    - Strengths and areas for improvement
    - Next question (if interview continues)
    - Final report (if interview complete)
    """
    if not INTERVIEW_ENABLED or not interview_system:
        raise HTTPException(status_code=503, detail="Interview system not available")
    
    try:
        result = interview_system.submit_answer(
            session_id=request.session_id,
            answer=request.answer
        )
        
        if not result.get('success'):
            raise HTTPException(status_code=400, detail=result.get('error', 'Failed to process answer'))
        
        return result
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing answer: {str(e)}")


@app.get("/api/interview/audio/{session_id}/{question_index}")
async def get_interview_audio(session_id: str, question_index: int):
    """
    🔊 Get Audio File for Interview Question
    
    Returns the audio file (MP3) of the AI asking the question.
    This enables voice-based interview experience.
    """
    if not INTERVIEW_ENABLED or not interview_system:
        raise HTTPException(status_code=503, detail="Interview system not available")
    
    try:
        from fastapi.responses import FileResponse
        
        audio_path = interview_system.get_audio_file(session_id, question_index)
        
        if not audio_path or not os.path.exists(audio_path):
            raise HTTPException(status_code=404, detail="Audio file not found")
        
        return FileResponse(
            audio_path,
            media_type="audio/mpeg",
            filename=f"question_{question_index}.mp3"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving audio: {str(e)}")


@app.get("/api/interview/session/{session_id}")
async def get_interview_session(session_id: str):
    """
    📊 Get Interview Session Details
    
    Retrieve current state of an interview session:
    - Progress (questions answered / total)
    - Current question
    - Past feedback
    - Session status
    """
    if not INTERVIEW_ENABLED or not interview_system:
        raise HTTPException(status_code=503, detail="Interview system not available")
    
    try:
        session = interview_system.get_session(session_id)
        
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        
        return {
            'success': True,
            'session_id': session['session_id'],
            'status': session['status'],
            'interview_type': session['interview_type'],
            'progress': {
                'current': session['current_question_index'],
                'total': len(session['questions'])
            },
            'started_at': session['started_at'],
            'completed_at': session.get('completed_at')
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving session: {str(e)}")


@app.get("/api/interview/status")
async def interview_system_status():
    """Check if mock interview system is available"""
    return {
        "available": INTERVIEW_ENABLED and interview_system is not None,
        "features": [
            "Resume parsing (PDF/DOCX)",
            "AI question generation based on resume",
            "Voice synthesis (Text-to-Speech)",
            "Real-time answer evaluation",
            "Interview types: Technical, Behavioral, HR",
            "Difficulty levels: Easy, Medium, Hard",
            "Comprehensive feedback and scoring",
            "Final interview report"
        ] if INTERVIEW_ENABLED else [],
        "message": "Mock Interview System ready" if INTERVIEW_ENABLED else "Install requirements-interview.txt to enable"
    }


# ============================================================================
# JOB APPLICATION AGENT ENDPOINTS
# ============================================================================

class JobMatchRequest(BaseModel):
    user_profile: dict
    job_title: str
    company: str
    job_description: str

class EmailGenerationRequest(BaseModel):
    user_profile: dict
    job_title: str
    company: str
    job_description: str
    tone: str = "professional"
    include_project: bool = True
    custom_notes: Optional[str] = None

class EmailImprovementRequest(BaseModel):
    original_email: str
    feedback: str

class FollowUpRequest(BaseModel):
    company: str
    job_title: str
    days_since_application: int
    original_email: str

@app.post("/api/jobs/analyze-match")
async def analyze_job_match(request: JobMatchRequest):
    """Analyze how well user profile matches a job"""
    if not JOB_AGENT_ENABLED or job_agent is None:
        raise HTTPException(status_code=503, detail="Job Application Agent not available")
    
    try:
        result = job_agent.analyze_job_match(
            user_profile=request.user_profile,
            job_description=request.job_description,
            job_title=request.job_title,
            company=request.company
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error analyzing job match: {str(e)}")

@app.post("/api/jobs/generate-email")
async def generate_application_email(request: EmailGenerationRequest):
    """Generate a personalized job application email"""
    if not JOB_AGENT_ENABLED or job_agent is None:
        raise HTTPException(status_code=503, detail="Job Application Agent not available")
    
    try:
        result = job_agent.generate_application_email(
            user_profile=request.user_profile,
            job_title=request.job_title,
            company=request.company,
            job_description=request.job_description,
            tone=request.tone,
            include_project=request.include_project,
            custom_notes=request.custom_notes
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating email: {str(e)}")

@app.post("/api/jobs/improve-email")
async def improve_email(request: EmailImprovementRequest):
    """Improve an existing email based on feedback"""
    if not JOB_AGENT_ENABLED or job_agent is None:
        raise HTTPException(status_code=503, detail="Job Application Agent not available")
    
    try:
        result = job_agent.improve_email(
            original_email=request.original_email,
            feedback=request.feedback
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error improving email: {str(e)}")

@app.post("/api/jobs/generate-follow-up")
async def generate_follow_up(request: FollowUpRequest):
    """Generate a follow-up email"""
    if not JOB_AGENT_ENABLED or job_agent is None:
        raise HTTPException(status_code=503, detail="Job Application Agent not available")
    
    try:
        result = job_agent.generate_follow_up_email(
            company=request.company,
            job_title=request.job_title,
            days_since_application=request.days_since_application,
            original_email=request.original_email
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating follow-up: {str(e)}")

@app.get("/api/jobs/status")
async def job_agent_status():
    """Check if Job Application Agent is available"""
    return {
        "enabled": JOB_AGENT_ENABLED and job_agent is not None,
        "features": [
            "Job match analysis",
            "Email generation",
            "Email improvement",
            "Follow-up emails"
        ] if JOB_AGENT_ENABLED else []
    }

# ============================================================================
# RESUME/CV OPTIMIZER ENDPOINTS
# ============================================================================

class ResumeAnalysisRequest(BaseModel):
    resume_text: str
    resume_summary: dict  # From resume_analyzer

class ResumeTailorRequest(BaseModel):
    resume_summary: dict
    job_title: str
    company: str
    job_description: str

class BulletPointsRequest(BaseModel):
    job_title: str
    responsibilities: List[str]
    achievements: Optional[List[str]] = None

@app.post("/api/resume/analyze")
async def analyze_resume(request: ResumeAnalysisRequest):
    """Analyze resume and provide comprehensive feedback"""
    if not RESUME_OPTIMIZER_ENABLED or resume_optimizer is None:
        raise HTTPException(status_code=503, detail="Resume Optimizer not available")
    
    try:
        result = resume_optimizer.analyze_resume(
            resume_text=request.resume_text,
            resume_summary=request.resume_summary
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error analyzing resume: {str(e)}")

@app.post("/api/resume/tailor")
async def tailor_resume(request: ResumeTailorRequest):
    """Tailor resume for specific job posting"""
    if not RESUME_OPTIMIZER_ENABLED or resume_optimizer is None:
        raise HTTPException(status_code=503, detail="Resume Optimizer not available")
    
    try:
        result = resume_optimizer.tailor_resume_for_job(
            resume_summary=request.resume_summary,
            job_title=request.job_title,
            job_description=request.job_description,
            company=request.company
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error tailoring resume: {str(e)}")

@app.post("/api/resume/generate-bullets")
async def generate_bullet_points(request: BulletPointsRequest):
    """Generate professional bullet points for resume"""
    if not RESUME_OPTIMIZER_ENABLED or resume_optimizer is None:
        raise HTTPException(status_code=503, detail="Resume Optimizer not available")
    
    try:
        result = resume_optimizer.generate_resume_bullet_points(
            job_title=request.job_title,
            responsibilities=request.responsibilities,
            achievements=request.achievements
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating bullet points: {str(e)}")

@app.get("/api/resume/status")
async def resume_optimizer_status():
    """Check if Resume Optimizer is available"""
    return {
        "enabled": RESUME_OPTIMIZER_ENABLED and resume_optimizer is not None,
        "features": [
            "Resume analysis and scoring",
            "Job-specific resume tailoring",
            "Professional bullet point generation",
            "ATS compatibility check",
            "Keyword optimization"
        ] if RESUME_OPTIMIZER_ENABLED else []
    }

# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))  # Default to 8080 for Cloud Run
    host = os.getenv("HOST", "0.0.0.0")
    
    print("\n" + "="*60)
    print("🎓 STUDENT AI PLATFORM")
    print("="*60)
    print(f"📚 Book Learning System: {'✅ ENABLED' if BOOKS_ENABLED else '❌ DISABLED'}")
    print(f"🧠 RAG System: {'✅ ENABLED' if RAG_ENABLED else '❌ DISABLED'}")
    print(f"🎤 Mock Interview System: {'✅ ENABLED' if INTERVIEW_ENABLED else '❌ DISABLED'}")
    print(f"💼 Job Application Agent: {'✅ ENABLED' if JOB_AGENT_ENABLED else '❌ DISABLED'}")
    print(f"📄 Resume Optimizer: {'✅ ENABLED' if RESUME_OPTIMIZER_ENABLED else '❌ DISABLED'}")
    
    # Check if internship scraper is available
    import os
    scraper_dir = os.path.join(os.path.dirname(__file__), '..', 'mcp-internship-scraper')
    scraper_path = os.path.join(scraper_dir, 'scraper.py')
    scraper_available = os.path.exists(scraper_path)
    print(f"🔍 Internship Scraper: {'✅ AVAILABLE' if scraper_available else '❌ NOT FOUND'}")
    if scraper_available:
        print(f"   📁 Path: {scraper_path}")
    
    print(f"🚀 Server starting on {host}:{port}")
    print("="*60 + "\n")
    
    uvicorn.run(app, host=host, port=port)

