"""
Mock Interview System - AI Interviewer
Generates interview questions and conducts voice-based interviews
"""

import os
import json
from typing import Dict, List, Optional
from datetime import datetime
from openai import OpenAI
from gtts import gTTS
from resume_analyzer import ResumeAnalyzer
import tempfile


class MockInterviewer:
    """AI-powered mock interview system with voice synthesis"""
    
    def __init__(self, ai_client=None):
        """Initialize the mock interviewer"""
        # Use provided AI client or create one
        if ai_client is None:
            from ai_client import UnifiedAIClient
            ai_client = UnifiedAIClient()
        
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
        self.resume_analyzer = ResumeAnalyzer()
        
        # Interview session storage
        self.sessions = {}
        self.audio_dir = "interview_audio"
        os.makedirs(self.audio_dir, exist_ok=True)
    
    def start_interview(
        self,
        resume_path: str,
        resume_type: str,
        user_id: str,
        interview_type: str = "technical",  # technical, behavioral, hr
        difficulty: str = "medium"  # easy, medium, hard
    ) -> Dict:
        """
        Start a new mock interview session
        
        Args:
            resume_path: Path to resume file
            resume_type: File type (pdf, docx)
            user_id: User identifier
            interview_type: Type of interview
            difficulty: Difficulty level
        
        Returns:
            Dictionary with session info and first question
        """
        # Parse resume
        resume_data = self.resume_analyzer.parse_resume(resume_path, resume_type)
        
        # Generate interview questions
        questions = self._generate_questions(
            resume_data,
            interview_type,
            difficulty
        )
        
        # Create session
        session_id = f"interview_{user_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        self.sessions[session_id] = {
            'session_id': session_id,
            'user_id': user_id,
            'resume_data': resume_data,
            'interview_type': interview_type,
            'difficulty': difficulty,
            'questions': questions,
            'current_question_index': 0,
            'answers': [],
            'feedback': [],
            'started_at': datetime.now().isoformat(),
            'status': 'in_progress'
        }
        
        # Get first question
        first_question = questions[0]
        
        # Generate voice for first question
        audio_path = self._text_to_speech(
            first_question['question'],
            session_id,
            0
        )
        
        return {
            'success': True,
            'session_id': session_id,
            'interview_type': interview_type,
            'total_questions': len(questions),
            'current_question': {
                'index': 0,
                'question': first_question['question'],
                'type': first_question['type'],
                'audio_url': f"/api/interview/audio/{session_id}/0"
            },
            'resume_summary': {
                'name': resume_data['extracted_info'].get('name'),
                'skills': resume_data['extracted_info'].get('skills', [])[:10],
                'experience': resume_data['extracted_info'].get('experience', [])[:3]
            }
        }
    
    def _generate_questions(
        self,
        resume_data: Dict,
        interview_type: str,
        difficulty: str
    ) -> List[Dict]:
        """
        Generate interview questions based on resume
        
        Args:
            resume_data: Parsed resume data
            interview_type: Type of interview
            difficulty: Difficulty level
        
        Returns:
            List of question dictionaries
        """
        extracted_info = resume_data['extracted_info']
        skills = extracted_info.get('skills', [])
        experience = extracted_info.get('experience', [])
        education = extracted_info.get('education', [])
        
        # Create prompt for question generation
        prompt = f"""You are an expert technical interviewer. Generate {5 if interview_type == 'technical' else 4} interview questions based on the candidate's resume.

Resume Summary:
- Skills: {', '.join(skills[:10]) if skills else 'General'}
- Experience: {', '.join([exp.get('title', 'Fresher') for exp in experience[:3]])}
- Education: {', '.join(education[:2]) if education else 'Not specified'}

Interview Type: {interview_type}
Difficulty: {difficulty}

Generate questions in this exact JSON format:
[
  {{
    "question": "Question text here",
    "type": "technical|behavioral|situational",
    "topic": "specific topic",
    "expected_points": ["point1", "point2", "point3"]
  }}
]

For technical interviews, focus on:
- Core programming concepts related to their skills
- System design (if experienced)
- Data structures and algorithms
- Problem-solving approach

For behavioral interviews, focus on:
- Past experiences
- Teamwork and collaboration
- Handling challenges
- Leadership skills

Make questions realistic and relevant to their background. Return ONLY valid JSON array."""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert interviewer. Always respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )
            
            questions_text = response.choices[0].message.content.strip()
            
            # Extract JSON from response
            json_start = questions_text.find('[')
            json_end = questions_text.rfind(']') + 1
            if json_start != -1 and json_end > json_start:
                questions_text = questions_text[json_start:json_end]
            
            questions = json.loads(questions_text)
            
            # Add IDs to questions
            for i, q in enumerate(questions):
                q['id'] = f"q_{i}"
            
            return questions
            
        except Exception as e:
            print(f"Error generating questions: {e}")
            # Return default questions as fallback
            return self._get_default_questions(interview_type, skills)
    
    def _get_default_questions(self, interview_type: str, skills: List[str]) -> List[Dict]:
        """Fallback default questions"""
        if interview_type == "technical":
            return [
                {
                    "id": "q_0",
                    "question": "Can you introduce yourself and tell me about your technical background?",
                    "type": "introduction",
                    "topic": "general",
                    "expected_points": ["education", "experience", "skills"]
                },
                {
                    "id": "q_1",
                    "question": f"I see you have experience with {skills[0] if skills else 'programming'}. Can you explain a challenging problem you solved using it?",
                    "type": "technical",
                    "topic": skills[0] if skills else "programming",
                    "expected_points": ["problem description", "solution approach", "outcome"]
                },
                {
                    "id": "q_2",
                    "question": "Explain the difference between a process and a thread. When would you use one over the other?",
                    "type": "technical",
                    "topic": "operating systems",
                    "expected_points": ["definitions", "differences", "use cases"]
                },
                {
                    "id": "q_3",
                    "question": "How do you approach debugging a complex issue in production?",
                    "type": "behavioral",
                    "topic": "problem-solving",
                    "expected_points": ["systematic approach", "tools used", "collaboration"]
                },
                {
                    "id": "q_4",
                    "question": "Where do you see yourself in the next 2-3 years, and how does this role fit into your career goals?",
                    "type": "hr",
                    "topic": "career goals",
                    "expected_points": ["clear goals", "alignment with role", "growth mindset"]
                }
            ]
        else:
            return [
                {
                    "id": "q_0",
                    "question": "Tell me about yourself and your professional journey.",
                    "type": "introduction",
                    "topic": "general",
                    "expected_points": ["background", "key achievements", "motivations"]
                },
                {
                    "id": "q_1",
                    "question": "Describe a time when you faced a difficult challenge at work. How did you handle it?",
                    "type": "behavioral",
                    "topic": "problem-solving",
                    "expected_points": ["situation", "action", "result"]
                },
                {
                    "id": "q_2",
                    "question": "Tell me about a time when you had to work with a difficult team member.",
                    "type": "behavioral",
                    "topic": "teamwork",
                    "expected_points": ["situation", "approach", "resolution"]
                },
                {
                    "id": "q_3",
                    "question": "What are your greatest strengths and weaknesses?",
                    "type": "hr",
                    "topic": "self-awareness",
                    "expected_points": ["honest assessment", "examples", "improvement plan"]
                }
            ]
    
    def submit_answer(
        self,
        session_id: str,
        answer: str
    ) -> Dict:
        """
        Submit answer to current question and get feedback + next question
        
        Args:
            session_id: Interview session ID
            answer: Student's answer
        
        Returns:
            Dictionary with feedback and next question (if any)
        """
        if session_id not in self.sessions:
            return {'success': False, 'error': 'Session not found'}
        
        session = self.sessions[session_id]
        current_index = session['current_question_index']
        current_question = session['questions'][current_index]
        
        # Evaluate answer
        feedback = self._evaluate_answer(
            current_question,
            answer,
            session['resume_data']
        )
        
        # Store answer and feedback
        session['answers'].append({
            'question_id': current_question['id'],
            'answer': answer,
            'timestamp': datetime.now().isoformat()
        })
        session['feedback'].append(feedback)
        
        # Move to next question
        session['current_question_index'] += 1
        next_index = session['current_question_index']
        
        # Check if interview is complete
        if next_index >= len(session['questions']):
            session['status'] = 'completed'
            session['completed_at'] = datetime.now().isoformat()
            
            # Generate final report
            report = self._generate_report(session)
            
            return {
                'success': True,
                'interview_complete': True,
                'current_feedback': feedback,
                'final_report': report
            }
        
        # Get next question
        next_question = session['questions'][next_index]
        
        # Generate voice for next question
        audio_path = self._text_to_speech(
            next_question['question'],
            session_id,
            next_index
        )
        
        return {
            'success': True,
            'interview_complete': False,
            'current_feedback': feedback,
            'next_question': {
                'index': next_index,
                'question': next_question['question'],
                'type': next_question['type'],
                'audio_url': f"/api/interview/audio/{session_id}/{next_index}"
            },
            'progress': {
                'answered': next_index,
                'total': len(session['questions'])
            }
        }
    
    def _evaluate_answer(
        self,
        question: Dict,
        answer: str,
        resume_data: Dict
    ) -> Dict:
        """
        Evaluate student's answer using AI
        
        Args:
            question: Question dictionary
            answer: Student's answer
            resume_data: Resume data for context
        
        Returns:
            Dictionary with feedback and score
        """
        prompt = f"""You are an expert interviewer evaluating a candidate's answer.

Question: {question['question']}
Type: {question['type']}
Expected Points: {', '.join(question.get('expected_points', []))}

Candidate's Answer:
{answer}

Provide evaluation in this exact JSON format:
{{
  "score": 7.5,
  "strengths": ["point1", "point2"],
  "areas_for_improvement": ["point1", "point2"],
  "feedback": "Brief constructive feedback (2-3 sentences)",
  "follow_up_suggestion": "Optional follow-up question or suggestion"
}}

Score from 0-10 where:
- 0-3: Poor answer, missing key points
- 4-6: Average answer, covers basics
- 7-8: Good answer, covers most points well
- 9-10: Excellent answer, comprehensive and insightful

Return ONLY valid JSON."""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert interviewer. Always respond with valid JSON only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=800
            )
            
            feedback_text = response.choices[0].message.content.strip()
            
            # Extract JSON
            json_start = feedback_text.find('{')
            json_end = feedback_text.rfind('}') + 1
            if json_start != -1 and json_end > json_start:
                feedback_text = feedback_text[json_start:json_end]
            
            feedback = json.loads(feedback_text)
            feedback['question_type'] = question['type']
            
            return feedback
            
        except Exception as e:
            print(f"Error evaluating answer: {e}")
            return {
                'score': 5.0,
                'strengths': ["Answer provided"],
                'areas_for_improvement': ["Could provide more detail"],
                'feedback': "Thank you for your answer. Consider providing more specific examples.",
                'question_type': question['type']
            }
    
    def _generate_report(self, session: Dict) -> Dict:
        """
        Generate final interview report
        
        Args:
            session: Interview session data
        
        Returns:
            Dictionary with comprehensive report
        """
        feedback_list = session['feedback']
        
        # Calculate scores
        scores = [f.get('score', 0) for f in feedback_list]
        average_score = sum(scores) / len(scores) if scores else 0
        
        # Group by question type
        technical_scores = [f.get('score', 0) for f in feedback_list if f.get('question_type') == 'technical']
        behavioral_scores = [f.get('score', 0) for f in feedback_list if f.get('question_type') == 'behavioral']
        
        # Collect all strengths and improvements
        all_strengths = []
        all_improvements = []
        
        for f in feedback_list:
            all_strengths.extend(f.get('strengths', []))
            all_improvements.extend(f.get('areas_for_improvement', []))
        
        # Overall assessment
        if average_score >= 8:
            overall = "Excellent"
        elif average_score >= 6:
            overall = "Good"
        elif average_score >= 4:
            overall = "Average"
        else:
            overall = "Needs Improvement"
        
        return {
            'session_id': session['session_id'],
            'interview_type': session['interview_type'],
            'overall_score': round(average_score, 2),
            'overall_assessment': overall,
            'scores_by_category': {
                'technical': round(sum(technical_scores) / len(technical_scores), 2) if technical_scores else None,
                'behavioral': round(sum(behavioral_scores) / len(behavioral_scores), 2) if behavioral_scores else None
            },
            'total_questions': len(session['questions']),
            'strengths': list(set(all_strengths))[:5],
            'areas_for_improvement': list(set(all_improvements))[:5],
            'duration_minutes': self._calculate_duration(session),
            'recommendations': self._generate_recommendations(average_score, all_improvements)
        }
    
    def _calculate_duration(self, session: Dict) -> int:
        """Calculate interview duration in minutes"""
        try:
            start = datetime.fromisoformat(session['started_at'])
            end = datetime.fromisoformat(session.get('completed_at', datetime.now().isoformat()))
            duration = (end - start).total_seconds() / 60
            return int(duration)
        except:
            return 0
    
    def _generate_recommendations(self, score: float, improvements: List[str]) -> List[str]:
        """Generate recommendations based on performance"""
        recommendations = []
        
        if score < 5:
            recommendations.append("Practice more mock interviews to build confidence")
            recommendations.append("Focus on articulating your thoughts clearly")
        
        if score < 7:
            recommendations.append("Provide more specific examples from your experience")
            recommendations.append("Work on structuring your answers using the STAR method")
        
        if any('technical' in imp.lower() for imp in improvements):
            recommendations.append("Review core technical concepts in your skill areas")
        
        if any('example' in imp.lower() for imp in improvements):
            recommendations.append("Prepare specific examples for common interview questions")
        
        if not recommendations:
            recommendations.append("Keep practicing to maintain your strong interview skills")
            recommendations.append("Focus on showcasing your unique experiences")
        
        return recommendations[:5]
    
    def _text_to_speech(self, text: str, session_id: str, question_index: int) -> str:
        """
        Convert text to speech using Google TTS
        
        Args:
            text: Text to convert
            session_id: Session identifier
            question_index: Question index
        
        Returns:
            Path to generated audio file
        """
        try:
            # Generate speech
            tts = gTTS(text=text, lang='en', slow=False)
            
            # Save audio file
            audio_filename = f"{session_id}_q{question_index}.mp3"
            audio_path = os.path.join(self.audio_dir, audio_filename)
            tts.save(audio_path)
            
            return audio_path
            
        except Exception as e:
            print(f"Error generating speech: {e}")
            return None
    
    def get_audio_file(self, session_id: str, question_index: int) -> Optional[str]:
        """Get path to audio file for a question"""
        audio_filename = f"{session_id}_q{question_index}.mp3"
        audio_path = os.path.join(self.audio_dir, audio_filename)
        
        if os.path.exists(audio_path):
            return audio_path
        return None
    
    def get_session(self, session_id: str) -> Optional[Dict]:
        """Get session data"""
        return self.sessions.get(session_id)

