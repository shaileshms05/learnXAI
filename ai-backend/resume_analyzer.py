"""
Resume Analyzer for Mock Interview System
Extracts key information from resumes to generate relevant interview questions
"""

import os
import re
from typing import Dict, List, Optional
import PyPDF2
from docx import Document
import pdfplumber


class ResumeAnalyzer:
    """Analyzes resumes and extracts key information"""
    
    def __init__(self):
        self.extracted_data = {}
    
    def parse_resume(self, file_path: str, file_type: str) -> Dict:
        """
        Parse resume and extract text
        
        Args:
            file_path: Path to resume file
            file_type: Type of file (pdf, docx)
        
        Returns:
            Dictionary with extracted information
        """
        text = ""
        
        if file_type.lower() == 'pdf':
            text = self._parse_pdf(file_path)
        elif file_type.lower() in ['docx', 'doc']:
            text = self._parse_docx(file_path)
        else:
            raise ValueError(f"Unsupported file type: {file_type}")
        
        # Extract structured information
        extracted_info = self._extract_information(text)
        
        return {
            'raw_text': text,
            'extracted_info': extracted_info,
            'file_name': os.path.basename(file_path)
        }
    
    def _parse_pdf(self, file_path: str) -> str:
        """Extract text from PDF"""
        text = ""
        
        try:
            # Try with pdfplumber first (better for complex PDFs)
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
        except Exception as e:
            print(f"pdfplumber failed: {e}, trying PyPDF2...")
            # Fallback to PyPDF2
            try:
                with open(file_path, 'rb') as file:
                    pdf_reader = PyPDF2.PdfReader(file)
                    for page in pdf_reader.pages:
                        text += page.extract_text() + "\n"
            except Exception as e2:
                print(f"PyPDF2 also failed: {e2}")
                raise ValueError("Could not parse PDF")
        
        return text
    
    def _parse_docx(self, file_path: str) -> str:
        """Extract text from DOCX"""
        doc = Document(file_path)
        text = ""
        
        for paragraph in doc.paragraphs:
            text += paragraph.text + "\n"
        
        return text
    
    def _extract_information(self, text: str) -> Dict:
        """
        Extract structured information from resume text
        
        Args:
            text: Raw resume text
        
        Returns:
            Dictionary with extracted information
        """
        info = {
            'name': self._extract_name(text),
            'email': self._extract_email(text),
            'phone': self._extract_phone(text),
            'skills': self._extract_skills(text),
            'education': self._extract_education(text),
            'experience': self._extract_experience(text),
            'projects': self._extract_projects(text),
            'certifications': self._extract_certifications(text),
        }
        
        return info
    
    def _extract_name(self, text: str) -> Optional[str]:
        """Extract name (usually in first few lines)"""
        lines = text.strip().split('\n')
        if lines:
            # Assume name is in first non-empty line
            for line in lines[:5]:
                line = line.strip()
                if line and len(line.split()) <= 4 and not '@' in line:
                    return line
        return None
    
    def _extract_email(self, text: str) -> Optional[str]:
        """Extract email address"""
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        match = re.search(email_pattern, text)
        return match.group(0) if match else None
    
    def _extract_phone(self, text: str) -> Optional[str]:
        """Extract phone number"""
        phone_pattern = r'[\+\(]?[1-9][0-9 .\-\(\)]{8,}[0-9]'
        match = re.search(phone_pattern, text)
        return match.group(0) if match else None
    
    def _extract_skills(self, text: str) -> List[str]:
        """Extract technical skills"""
        skills = []
        
        # Common skill keywords
        skill_keywords = [
            'python', 'java', 'javascript', 'typescript', 'c\\+\\+', 'c#', 'ruby', 'go', 'rust', 'swift',
            'react', 'angular', 'vue', 'node', 'express', 'django', 'flask', 'fastapi',
            'sql', 'mysql', 'postgresql', 'mongodb', 'redis', 'firebase',
            'aws', 'azure', 'gcp', 'docker', 'kubernetes', 'git',
            'machine learning', 'deep learning', 'ai', 'data science', 'nlp',
            'tensorflow', 'pytorch', 'scikit-learn', 'pandas', 'numpy',
            'html', 'css', 'tailwind', 'bootstrap',
            'agile', 'scrum', 'devops', 'ci/cd'
        ]
        
        text_lower = text.lower()
        
        for skill in skill_keywords:
            if re.search(r'\b' + skill + r'\b', text_lower):
                skills.append(skill.title())
        
        return list(set(skills))  # Remove duplicates
    
    def _extract_education(self, text: str) -> List[str]:
        """Extract education information"""
        education = []
        
        # Look for degree keywords
        degree_patterns = [
            r'bachelor.*?(?:of|in)\s+([A-Za-z\s]+)',
            r'master.*?(?:of|in)\s+([A-Za-z\s]+)',
            r'phd.*?(?:in)?\s+([A-Za-z\s]+)',
            r'b\.?tech|m\.?tech|b\.?e|m\.?e|b\.?sc|m\.?sc|mba|bba',
        ]
        
        for pattern in degree_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                education.append(match.group(0).strip())
        
        return education if education else ['Not specified']
    
    def _extract_experience(self, text: str) -> List[Dict]:
        """Extract work experience"""
        experience = []
        
        # Look for job titles and company names
        job_patterns = [
            r'(?:software|senior|junior|lead|senior)\s+(?:engineer|developer|architect|analyst)',
            r'(?:data|ml|ai)\s+(?:scientist|engineer|analyst)',
            r'(?:full stack|frontend|backend|mobile)\s+developer',
            r'(?:project|product)\s+manager',
            r'intern(?:ship)?'
        ]
        
        for pattern in job_patterns:
            matches = re.finditer(pattern, text, re.IGNORECASE)
            for match in matches:
                experience.append({
                    'title': match.group(0).strip()
                })
        
        return experience if experience else [{'title': 'Entry Level / Fresher'}]
    
    def _extract_projects(self, text: str) -> List[str]:
        """Extract project information"""
        projects = []
        
        # Look for project section
        lines = text.split('\n')
        in_project_section = False
        
        for line in lines:
            line_lower = line.lower().strip()
            
            if 'project' in line_lower and len(line_lower) < 30:
                in_project_section = True
                continue
            
            if in_project_section:
                if line.strip() and not line.startswith(' ') and len(line.strip()) > 15:
                    if any(keyword in line_lower for keyword in ['experience', 'education', 'skill', 'certification']):
                        break
                    projects.append(line.strip())
        
        return projects[:5] if projects else []  # Limit to 5 projects
    
    def _extract_certifications(self, text: str) -> List[str]:
        """Extract certifications"""
        certifications = []
        
        cert_keywords = [
            'aws certified', 'azure certified', 'google cloud certified',
            'certified kubernetes', 'cissp', 'comptia',
            'pmp', 'scrum master', 'agile certified'
        ]
        
        text_lower = text.lower()
        
        for cert in cert_keywords:
            if cert in text_lower:
                certifications.append(cert.title())
        
        return certifications

