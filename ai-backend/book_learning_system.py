"""
Book Learning System - Main orchestrator for "Upload → Learn → Master"

Manages the complete learning flow from upload to mastery
"""

import os
import json
from typing import List, Dict, Optional
from dataclasses import dataclass, asdict
from datetime import datetime

try:
    from document_processor import DocumentProcessor, Chapter, BookMetadata, ChunkProcessor, BOOKS_ENABLED
    from concept_extractor import ConceptExtractor, TeachingEngine, QuizGenerator, Concept, ConceptGraph
    from knowledge_base import EducationalKnowledgeBase as KnowledgeBase
except ImportError as e:
    print(f"Import error: {e}")
    BOOKS_ENABLED = False


@dataclass
class LearningProgress:
    """Tracks student's learning progress"""
    user_id: str
    book_id: str
    chapter_progress: Dict[int, float]  # chapter_num -> mastery_percentage
    concept_mastery: Dict[str, float]  # concept_id -> mastery_score
    quiz_scores: List[Dict]
    last_updated: str


@dataclass
class BookSession:
    """Represents a learning session for a book"""
    book_id: str
    metadata: BookMetadata
    chapters: List[Chapter]
    concepts: List[Concept]
    knowledge_graph: Optional[ConceptGraph] = None


class BookLearningSystem:
    """
    Main system for book-based learning
    
    Flow:
    1. Upload book → Process → Extract concepts
    2. Build knowledge graph
    3. Start teaching mode (chapter by chapter)
    4. Test understanding after each concept
    5. Generate quizzes
    6. Track mastery
    """
    
    def __init__(self, storage_dir: str = "books_data", ai_client=None):
        if not BOOKS_ENABLED:
            raise ImportError("Book processing not available. Install requirements-books.txt")
        
        self.storage_dir = storage_dir
        os.makedirs(storage_dir, exist_ok=True)
        os.makedirs(f"{storage_dir}/uploads", exist_ok=True)
        os.makedirs(f"{storage_dir}/processed", exist_ok=True)
        os.makedirs(f"{storage_dir}/progress", exist_ok=True)
        
        self.doc_processor = DocumentProcessor()
        self.chunk_processor = ChunkProcessor()
        
        # Get AI client (use provided one or create new one)
        if ai_client is None:
            try:
                from ai_client import UnifiedAIClient
                ai_client = UnifiedAIClient()
            except Exception as e:
                raise ValueError(f"AI client required for book learning system. Please set GOOGLE_API_KEY or CEREBRAS_API_KEY. Error: {e}")
        
        self.ai_client = ai_client
        
        # Initialize AI-powered components with unified client
        self.concept_extractor = ConceptExtractor(ai_client)
        self.teaching_engine = TeachingEngine(ai_client)
        self.quiz_generator = QuizGenerator(ai_client)
        
        self.knowledge_base = KnowledgeBase()
        
        self.sessions: Dict[str, BookSession] = {}
    
    def upload_book(
        self, 
        file_path: str, 
        file_type: str,
        user_id: str
    ) -> Dict:
        """
        Step 1: Upload and process a book
        
        Returns:
            Dict with book_id, metadata, and chapter list
        """
        try:
            # Process document
            metadata, chapters = self.doc_processor.process_document(file_path, file_type)
            
            # Generate book ID
            book_id = f"book_{user_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
            
            # Save processed book
            book_data = {
                'book_id': book_id,
                'user_id': user_id,
                'metadata': asdict(metadata),
                'chapters': [asdict(ch) for ch in chapters],
                'uploaded_at': datetime.now().isoformat()
            }
            
            with open(f"{self.storage_dir}/processed/{book_id}.json", 'w') as f:
                json.dump(book_data, f, indent=2)
            
            # Extract concepts (async in production)
            print(f"📚 Extracting concepts from {len(chapters)} chapters...")
            all_concepts = []
            
            for chapter in chapters[:3]:  # Process first 3 chapters for demo
                concepts = self.concept_extractor.extract_concepts(
                    chapter.content, 
                    chapter.number
                )
                all_concepts.extend(concepts)
                
                # Add to knowledge base for RAG
                self.knowledge_base.add_knowledge([{
                    'id': f"{book_id}_ch{chapter.number}",
                    'content': chapter.content,
                    'metadata': {
                        'book_id': book_id,
                        'chapter': chapter.number,
                        'title': chapter.title,
                        'type': 'book_chapter'
                    }
                }])
            
            # Build knowledge graph
            knowledge_graph = self.concept_extractor.build_knowledge_graph(all_concepts)
            
            # Create session
            session = BookSession(
                book_id=book_id,
                metadata=metadata,
                chapters=chapters,
                concepts=all_concepts,
                knowledge_graph=knowledge_graph
            )
            self.sessions[book_id] = session
            
            # Initialize progress
            progress = LearningProgress(
                user_id=user_id,
                book_id=book_id,
                chapter_progress={ch.number: 0.0 for ch in chapters},
                concept_mastery={c.id: 0.0 for c in all_concepts},
                quiz_scores=[],
                last_updated=datetime.now().isoformat()
            )
            
            self._save_progress(progress)
            
            return {
                'success': True,
                'book_id': book_id,
                'metadata': asdict(metadata),
                'chapters': [{'number': ch.number, 'title': ch.title} for ch in chapters],
                'total_concepts': len(all_concepts),
                'message': f'Successfully processed {metadata.title}'
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def start_teaching(
        self, 
        book_id: str, 
        chapter_num: int,
        style: str = "simple"
    ) -> Dict:
        """
        Step 2: Start teaching a chapter
        
        Returns:
            Teaching content for the first concept
        """
        session = self.sessions.get(book_id)
        if not session:
            return {'error': 'Book session not found'}
        
        # Get concepts for this chapter
        chapter_concepts = [c for c in session.concepts if c.chapter == chapter_num]
        
        if not chapter_concepts:
            return {'error': 'No concepts found for this chapter'}
        
        # Get chapter content for context
        chapter = next((ch for ch in session.chapters if ch.number == chapter_num), None)
        book_context = chapter.content[:2000] if chapter else ""
        
        # Teach first concept
        concept = chapter_concepts[0]
        teaching_content = self.teaching_engine.teach_concept(
            concept, 
            style=style,
            book_context=book_context
        )
        
        return {
            'success': True,
            'chapter': chapter_num,
            'concept': {
                'id': concept.id,
                'name': concept.name,
                'definition': concept.definition,
                'difficulty': concept.difficulty,
                'prerequisites': concept.prerequisites
            },
            'teaching': teaching_content,
            'total_concepts': len(chapter_concepts),
            'current_concept_index': 0
        }
    
    def check_understanding(
        self,
        book_id: str,
        concept_id: str,
        question: str,
        student_answer: str,
        user_id: str
    ) -> Dict:
        """
        Step 3: Check student's understanding
        
        Returns:
            Evaluation with score and feedback
        """
        session = self.sessions.get(book_id)
        if not session:
            return {'error': 'Book session not found'}
        
        # Find concept
        concept = next((c for c in session.concepts if c.id == concept_id), None)
        if not concept:
            return {'error': 'Concept not found'}
        
        # Evaluate answer
        evaluation = self.teaching_engine.evaluate_answer(
            concept, 
            question, 
            student_answer
        )
        
        # Update progress
        progress = self._load_progress(user_id, book_id)
        if progress:
            progress.concept_mastery[concept_id] = evaluation['score']
            progress.last_updated = datetime.now().isoformat()
            self._save_progress(progress)
            
            # Update chapter progress (average of concepts)
            chapter_concepts = [c for c in session.concepts if c.chapter == concept.chapter]
            chapter_scores = [progress.concept_mastery.get(c.id, 0) for c in chapter_concepts]
            progress.chapter_progress[concept.chapter] = sum(chapter_scores) / len(chapter_scores) if chapter_scores else 0
            self._save_progress(progress)
        
        return {
            'success': True,
            'evaluation': evaluation,
            'mastery_score': evaluation['score'],
            'next_action': 'continue' if evaluation['score'] >= 70 else 'review'
        }
    
    def generate_chapter_quiz(
        self,
        book_id: str,
        chapter_num: int
    ) -> Dict:
        """
        Step 4: Generate quiz for a chapter
        """
        session = self.sessions.get(book_id)
        if not session:
            return {'error': 'Book session not found'}
        
        # Get concepts for this chapter
        chapter_concepts = [c for c in session.concepts if c.chapter == chapter_num]
        
        if not chapter_concepts:
            return {'error': 'No concepts found for this chapter'}
        
        # Generate quiz
        questions = self.quiz_generator.generate_quiz(chapter_concepts, num_questions=5)
        
        return {
            'success': True,
            'chapter': chapter_num,
            'questions': questions,
            'total_questions': len(questions)
        }
    
    def get_mastery_dashboard(
        self,
        user_id: str,
        book_id: str
    ) -> Dict:
        """
        Step 5: Get mastery dashboard
        
        Returns:
            Progress visualization data
        """
        progress = self._load_progress(user_id, book_id)
        if not progress:
            return {'error': 'Progress not found'}
        
        session = self.sessions.get(book_id)
        
        # Calculate overall mastery
        all_scores = list(progress.concept_mastery.values())
        overall_mastery = sum(all_scores) / len(all_scores) if all_scores else 0
        
        # Chapter breakdown
        chapters_data = []
        for chapter_num, mastery in sorted(progress.chapter_progress.items()):
            chapter = next((ch for ch in session.chapters if ch.number == chapter_num), None) if session else None
            chapters_data.append({
                'chapter': chapter_num,
                'title': chapter.title if chapter else f'Chapter {chapter_num}',
                'mastery': round(mastery, 1),
                'status': 'mastered' if mastery >= 80 else 'in_progress' if mastery >= 50 else 'needs_work'
            })
        
        return {
            'success': True,
            'overall_mastery': round(overall_mastery, 1),
            'chapters': chapters_data,
            'total_concepts': len(progress.concept_mastery),
            'mastered_concepts': len([s for s in all_scores if s >= 80]),
            'last_updated': progress.last_updated
        }
    
    def chat_with_book(
        self,
        book_id: str,
        question: str
    ) -> Dict:
        """
        Step 6: Chat with the book (RAG-powered)
        
        Returns answers using ONLY the book content
        """
        session = self.sessions.get(book_id)
        if not session:
            return {'error': 'Book session not found'}
        
        # Query knowledge base (filtered by book_id)
        relevant_docs = self.knowledge_base.search(question, n_results=3)
        
        # Filter to this book only
        book_docs = [doc for doc in relevant_docs if doc.get('metadata', {}).get('book_id') == book_id]
        
        if not book_docs:
            return {
                'success': True,
                'answer': "I couldn't find relevant information about that in this book.",
                'sources': []
            }
        
        # Build context from book (limit to avoid token limits)
        context = "\n\n".join([
            f"[Chapter {doc['metadata']['chapter']}: {doc['metadata']['title']}]\n{doc['content'][:1500]}..."
            for doc in book_docs[:2]  # Only use top 2 results
        ])
        
        # Generate answer using unified AI client
        prompt = f"""
You are a teaching assistant for the book "{session.metadata.title}".
Answer the question using ONLY information from the book excerpts below.

Book Excerpts:
{context}

Student Question: {question}

Provide a clear answer with:
1. Direct answer
2. Page/chapter references
3. Related concepts to explore

Answer:
"""
        
        try:
            response = self.ai_client.chat.completions.create(
                model=getattr(self.ai_client, 'model_name', 'gemini-2.5-flash'),
                messages=[
                    {"role": "system", "content": "You are a teaching assistant. Answer using only the provided book content."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=1000
            )
            
            answer = response.choices[0].message.content.strip()
            
            sources = [
                {
                    'chapter': doc['metadata']['chapter'],
                    'title': doc['metadata']['title']
                }
                for doc in book_docs
            ]
            
            return {
                'success': True,
                'answer': answer,
                'sources': sources
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
    
    def _save_progress(self, progress: LearningProgress):
        """Save learning progress"""
        filename = f"{self.storage_dir}/progress/{progress.user_id}_{progress.book_id}.json"
        with open(filename, 'w') as f:
            json.dump(asdict(progress), f, indent=2)
    
    def _load_progress(self, user_id: str, book_id: str) -> Optional[LearningProgress]:
        """Load learning progress"""
        filename = f"{self.storage_dir}/progress/{user_id}_{book_id}.json"
        if not os.path.exists(filename):
            return None
        
        with open(filename, 'r') as f:
            data = json.load(f)
            return LearningProgress(**data)


# Test
if __name__ == "__main__":
    if BOOKS_ENABLED:
        print("✅ Book Learning System initialized")
        print("Features:")
        print("  - Upload & process books (PDF, EPUB, DOCX)")
        print("  - Extract concepts & build knowledge graph")
        print("  - Adaptive teaching engine")
        print("  - Understanding checks")
        print("  - Quiz generation")
        print("  - Mastery tracking")
        print("  - Book-specific chat (RAG)")
    else:
        print("❌ Install requirements: pip install -r requirements-books.txt")

