"""
AI Job Application Agent
Helps students draft professional job application emails
"""

import json
from typing import Dict, List, Optional
from datetime import datetime


class JobApplicationAgent:
    """AI agent for generating job application emails and analyzing job matches"""
    
    def __init__(self, ai_client):
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
    
    def analyze_job_match(
        self,
        user_profile: Dict,
        job_description: str,
        job_title: str,
        company: str
    ) -> Dict:
        """
        Analyze how well user's profile matches the job requirements
        Returns match score and recommendations
        """
        try:
            prompt = f"""Analyze this job match:

USER PROFILE:
- Skills: {', '.join(user_profile.get('skills', []))}
- Interests: {', '.join(user_profile.get('interests', []))}
- Experience: {', '.join(user_profile.get('experience', []))}
- Education: {user_profile.get('education', 'Not specified')}

JOB POSTING:
Company: {company}
Title: {job_title}
Description: {job_description}

Provide a JSON response with:
1. overall_score: 0-100 match percentage
2. matching_skills: list of user skills that match job requirements
3. missing_skills: list of skills mentioned in job that user lacks
4. recommendations: list of 3-5 specific actions to improve match
5. summary: 2-3 sentence summary of the match

Return ONLY valid JSON, no other text."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a career counselor analyzing job matches. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1000
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON from response
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            result = json.loads(result_text)
            
            return {
                "success": True,
                "match_score": result,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error analyzing job match: {e}")
            return {
                "success": False,
                "error": str(e),
                "match_score": {
                    "overall_score": 0,
                    "matching_skills": [],
                    "missing_skills": [],
                    "recommendations": ["Unable to analyze at this time"],
                    "summary": "Analysis failed"
                }
            }
    
    def generate_application_email(
        self,
        user_profile: Dict,
        job_title: str,
        company: str,
        job_description: str,
        tone: str = "professional",
        include_project: bool = True,
        custom_notes: Optional[str] = None
    ) -> Dict:
        """
        Generate a personalized job application email
        
        Args:
            user_profile: User's skills, experience, education
            job_title: Position applying for
            company: Company name
            job_description: Job posting details
            tone: professional, enthusiastic, casual
            include_project: Whether to mention Student AI Platform project
            custom_notes: Additional points user wants to include
        """
        try:
            # Build project description if needed
            project_section = ""
            if include_project:
                project_section = """
Recently, I developed a comprehensive Student AI Platform that demonstrates my capabilities:
• Built with Flutter (mobile/web) and Python FastAPI backend
• Integrated Cerebras AI for personalized learning paths and career guidance
• Implemented RAG system for intelligent book learning with ChromaDB
• Created AI-powered mock interview system with voice synthesis
• Designed modern, industry-standard UI with Material Design 3

This project showcases my ability to build full-stack applications, integrate AI/ML technologies, and create intuitive user experiences.
"""
            
            custom_section = ""
            if custom_notes:
                custom_section = f"\n\nAdditional points:\n{custom_notes}"
            
            prompt = f"""Generate a professional job application email:

USER PROFILE:
- Name: {user_profile.get('name', 'Student')}
- Skills: {', '.join(user_profile.get('skills', []))}
- Interests: {', '.join(user_profile.get('interests', []))}
- Experience: {', '.join(user_profile.get('experience', []))}
- Education: {user_profile.get('education', 'Computer Science Student')}

JOB DETAILS:
- Company: {company}
- Position: {job_title}
- Description: {job_description}

REQUIREMENTS:
- Tone: {tone}
- Include project: {include_project}
{custom_section}

Generate a complete email with:
1. Subject line
2. Professional greeting
3. Opening paragraph (express interest)
4. Body (highlight relevant skills and experience)
{project_section if include_project else ''}
5. Why interested in this company/role
6. Closing (call to action)
7. Professional signature

Make it personalized, specific to the job, and compelling. Keep it concise (300-400 words).
Return as JSON with 'subject' and 'body' fields."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert career counselor who writes compelling job application emails. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,
                max_tokens=1500
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON from response
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            # If not JSON format, create it manually
            if not result_text.startswith('{'):
                # Extract subject and body
                lines = result_text.split('\n')
                subject = lines[0].replace('Subject:', '').strip()
                body = '\n'.join(lines[1:]).strip()
                result = {"subject": subject, "body": body}
            else:
                result = json.loads(result_text)
            
            return {
                "success": True,
                "email": result,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error generating email: {e}")
            return {
                "success": False,
                "error": str(e),
                "email": {
                    "subject": f"Application for {job_title} - {user_profile.get('name', 'Student')}",
                    "body": "Error generating email. Please try again."
                }
            }
    
    def improve_email(
        self,
        original_email: str,
        feedback: str
    ) -> Dict:
        """
        Improve an existing email based on user feedback
        """
        try:
            prompt = f"""Improve this job application email based on feedback:

ORIGINAL EMAIL:
{original_email}

USER FEEDBACK:
{feedback}

Generate an improved version that addresses the feedback while maintaining professionalism.
Return as JSON with 'subject' and 'body' fields."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert at improving job application emails. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1500
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            result = json.loads(result_text)
            
            return {
                "success": True,
                "improved_email": result,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error improving email: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def generate_follow_up_email(
        self,
        company: str,
        job_title: str,
        days_since_application: int,
        original_email: str
    ) -> Dict:
        """
        Generate a follow-up email after applying
        """
        try:
            prompt = f"""Generate a professional follow-up email:

CONTEXT:
- Company: {company}
- Position: {job_title}
- Days since application: {days_since_application}
- Original application: {original_email[:200]}...

Generate a polite follow-up email that:
1. References the original application
2. Reiterates interest
3. Asks about timeline
4. Remains professional and not pushy

Return as JSON with 'subject' and 'body' fields."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert at writing professional follow-up emails. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=800
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            result = json.loads(result_text)
            
            return {
                "success": True,
                "follow_up_email": result,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error generating follow-up: {e}")
            return {
                "success": False,
                "error": str(e)
            }


# Check if dependencies are available
JOB_AGENT_ENABLED = True

try:
    import json
except ImportError:
    JOB_AGENT_ENABLED = False
    print("⚠️  Job Application Agent requires json module")

