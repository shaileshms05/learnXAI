"""
Concept Extraction & Knowledge Graph Module

Extracts concepts, builds dependency graphs, and creates learning paths
"""

import json
from typing import List, Dict, Set, Optional
from dataclasses import dataclass, asdict
from openai import OpenAI
import os

try:
    import networkx as nx
    GRAPH_ENABLED = True
except ImportError:
    GRAPH_ENABLED = False
    print("⚠️  NetworkX not installed. Run: pip install networkx")


@dataclass
class Concept:
    """Represents a learning concept"""
    id: str
    name: str
    definition: str
    chapter: int
    difficulty: str  # "beginner", "intermediate", "advanced"
    prerequisites: List[str]  # IDs of prerequisite concepts
    examples: List[str]
    keywords: List[str]


@dataclass
class ConceptGraph:
    """Knowledge graph of concepts"""
    concepts: Dict[str, Concept]
    dependencies: Dict[str, List[str]]  # concept_id -> [prerequisite_ids]


class ConceptExtractor:
    """Extracts concepts from text using AI"""
    
    def __init__(self, ai_client=None):
        # Use provided AI client or try to get from global scope
        if ai_client is None:
            try:
                from ai_client import UnifiedAIClient
                ai_client = UnifiedAIClient()
            except Exception as e:
                raise ValueError(f"AI client not available. Please ensure GOOGLE_API_KEY or CEREBRAS_API_KEY is set. Error: {e}")
        
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
    
    def extract_concepts(self, text: str, chapter_num: int) -> List[Concept]:
        """
        Extract key concepts from text using AI
        
        Args:
            text: Chapter or section text
            chapter_num: Chapter number
            
        Returns:
            List of extracted concepts
        """
        prompt = f"""
You are an expert educational content analyzer. Extract the KEY CONCEPTS from this text.

For each concept, identify:
1. Name (concise, 2-5 words)
2. Definition (1-2 sentences)
3. Difficulty level (beginner/intermediate/advanced)
4. Prerequisites (what should be learned first)
5. Examples mentioned in the text
6. Keywords

Text:
{text[:3000]}  # Limit to avoid token limits

Return a JSON array of concepts:
[
  {{
    "name": "Neural Network",
    "definition": "A computational model inspired by biological neural networks",
    "difficulty": "intermediate",
    "prerequisites": ["Linear Algebra", "Calculus"],
    "examples": ["Image classification", "Speech recognition"],
    "keywords": ["neurons", "layers", "weights", "activation"]
  }}
]

Extract 3-7 main concepts. Return ONLY the JSON array.
"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert at extracting learning concepts. Always return valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=2000
            )
            
            result = response.choices[0].message.content.strip()
            
            # Clean markdown
            if result.startswith("```json"):
                result = result[7:]
            if result.startswith("```"):
                result = result[3:]
            if result.endswith("```"):
                result = result[:-3]
            result = result.strip()
            
            concepts_data = json.loads(result)
            
            # Convert to Concept objects
            concepts = []
            for i, data in enumerate(concepts_data):
                concept = Concept(
                    id=f"ch{chapter_num}_c{i}",
                    name=data.get('name', 'Unknown'),
                    definition=data.get('definition', ''),
                    chapter=chapter_num,
                    difficulty=data.get('difficulty', 'intermediate'),
                    prerequisites=data.get('prerequisites', []),
                    examples=data.get('examples', []),
                    keywords=data.get('keywords', [])
                )
                concepts.append(concept)
            
            return concepts
            
        except Exception as e:
            print(f"Error extracting concepts: {e}")
            return []
    
    def build_knowledge_graph(self, all_concepts: List[Concept]) -> ConceptGraph:
        """
        Build a knowledge graph from concepts
        
        Args:
            all_concepts: List of all concepts from the book
            
        Returns:
            ConceptGraph with dependencies
        """
        concepts_dict = {c.id: c for c in all_concepts}
        dependencies = {}
        
        # Build dependency map
        for concept in all_concepts:
            # Find prerequisite concept IDs
            prereq_ids = []
            for prereq_name in concept.prerequisites:
                # Match prerequisite names to concept IDs
                for other_concept in all_concepts:
                    if prereq_name.lower() in other_concept.name.lower():
                        prereq_ids.append(other_concept.id)
                        break
            
            dependencies[concept.id] = prereq_ids
        
        return ConceptGraph(
            concepts=concepts_dict,
            dependencies=dependencies
        )


class TeachingEngine:
    """Adaptive teaching engine"""
    
    def __init__(self, ai_client=None):
        # Use provided AI client or try to get from global scope
        if ai_client is None:
            try:
                from ai_client import UnifiedAIClient
                ai_client = UnifiedAIClient()
            except Exception as e:
                raise ValueError(f"AI client not available. Please ensure GOOGLE_API_KEY or CEREBRAS_API_KEY is set. Error: {e}")
        
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
    
    def teach_concept(
        self, 
        concept: Concept, 
        style: str = "simple",
        book_context: str = ""
    ) -> Dict[str, str]:
        """
        Teach a concept with adaptive explanation
        
        Args:
            concept: The concept to teach
            style: Teaching style (simple, code-first, math-heavy, interview)
            book_context: Original text from book for reference
            
        Returns:
            Dict with explanation, example, and question
        """
        style_prompts = {
            "simple": "Explain this like I'm 12 years old. Use simple analogies.",
            "code-first": "Explain with code examples and practical implementation.",
            "math-heavy": "Explain with mathematical rigor and formulas.",
            "interview": "Explain from an interview preparation perspective."
        }
        
        style_instruction = style_prompts.get(style, style_prompts["simple"])
        
        prompt = f"""
You are an expert teacher. Teach this concept:

**Concept:** {concept.name}
**Definition:** {concept.definition}
**Difficulty:** {concept.difficulty}
**Prerequisites:** {', '.join(concept.prerequisites) if concept.prerequisites else 'None'}

**Book Context:**
{book_context[:1000] if book_context else 'No additional context'}

**Teaching Style:** {style_instruction}

Provide:
1. **Explanation** (2-3 paragraphs, clear and engaging)
2. **Example** (concrete, relatable example)
3. **Check Question** (to test understanding)

Format as JSON:
{{
  "explanation": "...",
  "example": "...",
  "question": "..."
}}
"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert teacher. Always return valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1500
            )
            
            result = response.choices[0].message.content.strip()
            
            # Clean markdown
            if result.startswith("```json"):
                result = result[7:]
            if result.startswith("```"):
                result = result[3:]
            if result.endswith("```"):
                result = result[:-3]
            result = result.strip()
            
            # Remove control characters that break JSON
            import re
            result = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', result)
            
            teaching_content = json.loads(result)
            return teaching_content
            
        except Exception as e:
            print(f"Error teaching concept: {e}")
            return {
                "explanation": f"Error generating explanation: {e}",
                "example": "",
                "question": ""
            }
    
    def evaluate_answer(
        self, 
        concept: Concept, 
        question: str, 
        student_answer: str
    ) -> Dict[str, any]:
        """
        Evaluate student's answer to understanding check
        
        Returns:
            Dict with score, feedback, and missing concepts
        """
        prompt = f"""
You are evaluating a student's understanding of a concept.

**Concept:** {concept.name}
**Definition:** {concept.definition}

**Question:** {question}
**Student's Answer:** {student_answer}

Evaluate:
1. **Score** (0-100): How well did they understand?
2. **Feedback** (2-3 sentences): What they got right/wrong
3. **Missing Ideas** (list): What key ideas are missing?
4. **Misconceptions** (list): Any incorrect understanding?

Return JSON:
{{
  "score": 85,
  "feedback": "...",
  "missing_ideas": ["..."],
  "misconceptions": ["..."]
}}
"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are an expert evaluator. Always return valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=800
            )
            
            result = response.choices[0].message.content.strip()
            
            # Clean markdown
            if result.startswith("```json"):
                result = result[7:]
            if result.startswith("```"):
                result = result[3:]
            if result.endswith("```"):
                result = result[:-3]
            result = result.strip()
            
            # Remove control characters
            import re
            result = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', result)
            
            evaluation = json.loads(result)
            return evaluation
            
        except Exception as e:
            print(f"Error evaluating answer: {e}")
            return {
                "score": 0,
                "feedback": f"Error: {e}",
                "missing_ideas": [],
                "misconceptions": []
            }


class QuizGenerator:
    """Generates quizzes from concepts"""
    
    def __init__(self, ai_client=None):
        # Use provided AI client or try to get from global scope
        if ai_client is None:
            try:
                from ai_client import UnifiedAIClient
                ai_client = UnifiedAIClient()
            except Exception as e:
                raise ValueError(f"AI client not available. Please ensure GOOGLE_API_KEY or CEREBRAS_API_KEY is set. Error: {e}")
        
        self.client = ai_client
        # Use the model from the client (dynamic based on provider)
        self.model = getattr(ai_client, 'model_name', 'gemini-2.5-flash')
    
    def generate_quiz(
        self, 
        concepts: List[Concept], 
        num_questions: int = 5
    ) -> List[Dict]:
        """Generate quiz questions from concepts"""
        
        concepts_summary = "\n".join([
            f"- {c.name}: {c.definition}" for c in concepts[:5]
        ])
        
        prompt = f"""
Generate {num_questions} quiz questions based on these concepts:

{concepts_summary}

Create a mix of:
- Multiple choice (MCQ)
- Short answer
- Explain why

Return JSON array:
[
  {{
    "type": "mcq",
    "question": "What is...?",
    "options": ["A", "B", "C", "D"],
    "correct_answer": "B",
    "explanation": "Because..."
  }},
  {{
    "type": "short_answer",
    "question": "Explain...",
    "key_points": ["point1", "point2"]
  }}
]
"""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a quiz generator. Always return valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )
            
            result = response.choices[0].message.content.strip()
            
            # Clean markdown
            if result.startswith("```json"):
                result = result[7:]
            if result.startswith("```"):
                result = result[3:]
            if result.endswith("```"):
                result = result[:-3]
            result = result.strip()
            
            # Remove control characters
            import re
            result = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', result)
            
            questions = json.loads(result)
            return questions
            
        except Exception as e:
            print(f"Error generating quiz: {e}")
            return []


# Test
if __name__ == "__main__":
    print("✅ Concept extractor initialized")
    print("Features: Concept extraction, Knowledge graphs, Teaching engine, Quiz generation")

