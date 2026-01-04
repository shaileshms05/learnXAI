"""
AI Resume/CV Analyzer and Optimizer
Analyzes resumes and provides improvement suggestions
"""

from typing import Dict, List, Optional
from datetime import datetime
import re


class ResumeOptimizer:
    """AI-powered resume analysis and optimization"""
    
    def __init__(self, ai_client):
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
    
    def analyze_resume(self, resume_text: str, resume_summary: Dict) -> Dict:
        """
        Comprehensive resume analysis with scoring and suggestions
        
        Args:
            resume_text: Raw text extracted from resume
            resume_summary: Parsed resume data (name, skills, experience, etc.)
        
        Returns:
            Analysis with score, strengths, weaknesses, and suggestions
        """
        try:
            prompt = f"""Analyze this resume and provide a comprehensive evaluation:

RESUME CONTENT:
Name: {resume_summary.get('name', 'Not provided')}
Email: {resume_summary.get('email', 'Not provided')}

Skills: {', '.join(resume_summary.get('skills', []))}
Experience: {', '.join(resume_summary.get('experience', []))}
Education: {', '.join(resume_summary.get('education', []))}

FULL TEXT:
{resume_text[:2000]}...

Provide analysis in JSON format:
{{
  "overall_score": 0-100,
  "section_scores": {{
    "formatting": 0-100,
    "content": 0-100,
    "skills": 0-100,
    "experience": 0-100,
    "achievements": 0-100,
    "ats_compatibility": 0-100
  }},
  "strengths": [
    "List of 3-5 strong points"
  ],
  "weaknesses": [
    "List of 3-5 areas to improve"
  ],
  "missing_sections": [
    "Sections that should be added"
  ],
  "suggestions": [
    "5-7 specific, actionable improvement suggestions"
  ],
  "keyword_optimization": {{
    "strong_keywords": ["list"],
    "missing_keywords": ["list"],
    "suggestions": ["add X", "emphasize Y"]
  }},
  "ats_issues": [
    "Issues that might affect ATS parsing"
  ]
}}

Return ONLY valid JSON."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert resume reviewer and career coach. Provide honest, constructive feedback. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            import json
            analysis = json.loads(result_text)
            
            return {
                "success": True,
                "analysis": analysis,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error analyzing resume: {e}")
            return {
                "success": False,
                "error": str(e),
                "analysis": self._generate_fallback_analysis(resume_summary)
            }
    
    def tailor_resume_for_job(
        self,
        resume_summary: Dict,
        job_title: str,
        job_description: str,
        company: str
    ) -> Dict:
        """
        Tailor resume content to match specific job posting
        
        Args:
            resume_summary: Current resume data
            job_title: Target job title
            job_description: Job posting description
            company: Company name
        
        Returns:
            Optimized resume content suggestions
        """
        try:
            prompt = f"""Optimize this resume for the following job:

CURRENT RESUME:
Name: {resume_summary.get('name', 'Candidate')}
Skills: {', '.join(resume_summary.get('skills', []))}
Experience: {', '.join(resume_summary.get('experience', []))}

TARGET JOB:
Company: {company}
Title: {job_title}
Description: {job_description}

Provide tailored resume suggestions in JSON:
{{
  "optimized_summary": "Professional summary optimized for this job (2-3 sentences)",
  "skills_to_emphasize": [
    "Skills from resume that match job requirements"
  ],
  "skills_to_add": [
    "Related skills they should mention if they have them"
  ],
  "experience_bullets": [
    {{
      "original": "their experience item",
      "optimized": "rewritten to highlight relevant aspects for this job",
      "why": "explanation of changes"
    }}
  ],
  "keywords_to_include": [
    "Important keywords from job description"
  ],
  "projects_to_highlight": [
    "Which projects or achievements to emphasize"
  ],
  "overall_strategy": "Brief strategy for tailoring (2-3 sentences)"
}}

Return ONLY valid JSON."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a resume optimization expert. Help candidates tailor their resume to specific jobs. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            import json
            optimization = json.loads(result_text)
            
            return {
                "success": True,
                "optimization": optimization,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error tailoring resume: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def generate_resume_bullet_points(
        self,
        job_title: str,
        responsibilities: List[str],
        achievements: Optional[List[str]] = None
    ) -> Dict:
        """
        Generate professional bullet points for resume experience section
        
        Args:
            job_title: Job title
            responsibilities: List of responsibilities
            achievements: Optional list of achievements
        
        Returns:
            Professional bullet points
        """
        try:
            achievements_text = ""
            if achievements:
                achievements_text = f"\nAchievements: {', '.join(achievements)}"
            
            prompt = f"""Generate 5-7 professional resume bullet points for this role:

Job Title: {job_title}
Responsibilities: {', '.join(responsibilities)}
{achievements_text}

Requirements:
- Use action verbs (Led, Developed, Implemented, etc.)
- Include quantifiable metrics where possible
- Highlight impact and results
- Keep each bullet to 1-2 lines
- Focus on achievements, not just duties
- Use strong, industry-appropriate language

Return as JSON:
{{
  "bullet_points": [
    "Professionally written bullet point 1",
    "Professionally written bullet point 2",
    ...
  ],
  "tips": [
    "Suggestion for strengthening each bullet"
  ]
}}

Return ONLY valid JSON."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a professional resume writer. Create compelling, achievement-focused bullet points. Return only valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,
                max_tokens=1500
            )
            
            result_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            import json
            result = json.loads(result_text)
            
            return {
                "success": True,
                "result": result,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Error generating bullet points: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def _generate_fallback_analysis(self, resume_summary: Dict) -> Dict:
        """Generate basic analysis if AI fails"""
        skills_count = len(resume_summary.get('skills', []))
        experience_count = len(resume_summary.get('experience', []))
        
        # Calculate basic score
        score = 50  # Base score
        if skills_count >= 5: score += 15
        if experience_count >= 2: score += 15
        if resume_summary.get('email'): score += 10
        if resume_summary.get('education'): score += 10
        
        return {
            "overall_score": min(score, 100),
            "section_scores": {
                "formatting": 70,
                "content": score,
                "skills": min(skills_count * 10, 100),
                "experience": min(experience_count * 20, 100),
                "achievements": 60,
                "ats_compatibility": 65
            },
            "strengths": [
                "Resume successfully parsed",
                f"Contains {skills_count} skills",
                f"Has {experience_count} experience entries"
            ],
            "weaknesses": [
                "Unable to perform detailed AI analysis",
                "Consider adding more quantifiable achievements",
                "Review formatting for ATS compatibility"
            ],
            "missing_sections": [],
            "suggestions": [
                "Add quantifiable metrics to achievements",
                "Include relevant keywords for your industry",
                "Ensure consistent formatting throughout",
                "Add a professional summary at the top",
                "Include links to portfolio or LinkedIn"
            ],
            "keyword_optimization": {
                "strong_keywords": resume_summary.get('skills', [])[:3],
                "missing_keywords": [],
                "suggestions": ["Add industry-specific keywords"]
            },
            "ats_issues": [
                "Ensure simple formatting without tables or columns",
                "Use standard section headings",
                "Save as .docx or plain PDF"
            ]
        }


# Check if dependencies are available
RESUME_OPTIMIZER_ENABLED = True

try:
    import json
except ImportError:
    RESUME_OPTIMIZER_ENABLED = False
    print("⚠️  Resume Optimizer requires json module")

