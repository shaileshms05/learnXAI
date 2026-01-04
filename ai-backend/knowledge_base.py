"""
RAG (Retrieval Augmented Generation) System for Student AI Platform

This module implements a knowledge base system that improves AI responses
without requiring model training. It uses semantic search to find relevant
educational content and augments AI prompts with this knowledge.
"""

import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from typing import List, Dict
import json

class EducationalKnowledgeBase:
    """
    Manages educational knowledge and provides semantic search capabilities.
    """
    
    def __init__(self, persist_directory="./knowledge_base"):
        """Initialize the knowledge base with ChromaDB and sentence embeddings."""
        self.client = chromadb.Client(Settings(
            persist_directory=persist_directory,
            anonymized_telemetry=False
        ))
        
        # Use sentence-transformers for embeddings
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        
        # Create or get collection
        self.collection = self.client.get_or_create_collection(
            name="educational_knowledge",
            metadata={"description": "Student career and education knowledge base"}
        )
        
    def add_knowledge(self, documents: List[Dict]):
        """
        Add educational content to the knowledge base.
        
        Args:
            documents: List of dicts with 'id', 'content', 'metadata'
        """
        ids = [doc['id'] for doc in documents]
        contents = [doc['content'] for doc in documents]
        metadatas = [doc.get('metadata', {}) for doc in documents]
        
        # Generate embeddings
        embeddings = self.embedding_model.encode(contents).tolist()
        
        # Add to collection
        self.collection.add(
            ids=ids,
            documents=contents,
            embeddings=embeddings,
            metadatas=metadatas
        )
        
    def search(self, query: str, n_results: int = 3) -> List[Dict]:
        """
        Search for relevant knowledge based on query.
        
        Args:
            query: Search query
            n_results: Number of results to return
            
        Returns:
            List of relevant documents with metadata
        """
        # Generate query embedding
        query_embedding = self.embedding_model.encode([query])[0].tolist()
        
        # Search
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results
        )
        
        # Format results
        documents = []
        if results['documents'] and results['documents'][0]:
            for i in range(len(results['documents'][0])):
                documents.append({
                    'content': results['documents'][0][i],
                    'metadata': results['metadatas'][0][i] if results['metadatas'] else {},
                    'distance': results['distances'][0][i] if results['distances'] else None
                })
        
        return documents

# Initialize knowledge base
knowledge_base = EducationalKnowledgeBase()

# Seed with initial educational content
INITIAL_KNOWLEDGE = [
    {
        'id': 'career_software_eng_1',
        'content': """Software Engineering Career Path: Start with learning programming fundamentals 
        (Python, JavaScript). Build projects and contribute to open source. Get internships early. 
        Focus on data structures and algorithms. Typical timeline: 2-4 years from beginner to job-ready. 
        Key skills: coding, problem-solving, system design, version control (Git).""",
        'metadata': {'category': 'career', 'field': 'software_engineering'}
    },
    {
        'id': 'career_data_science_1',
        'content': """Data Science Career Path: Master statistics, Python, and SQL. Learn machine learning 
        fundamentals. Work on real datasets. Build portfolio projects. Typical timeline: 1-3 years. 
        Key skills: Python, pandas, scikit-learn, statistics, data visualization, SQL.""",
        'metadata': {'category': 'career', 'field': 'data_science'}
    },
    {
        'id': 'internship_prep_1',
        'content': """Internship Preparation: Update your resume with relevant projects. Practice coding 
        interviews (LeetCode, HackerRank). Build a strong GitHub profile. Network on LinkedIn. 
        Apply early (3-6 months before start date). Prepare behavioral questions using STAR method.""",
        'metadata': {'category': 'internship', 'type': 'preparation'}
    },
    {
        'id': 'learning_path_web_1',
        'content': """Web Development Learning Path: Start with HTML, CSS, JavaScript fundamentals. 
        Learn React or Vue for frontend. Learn Node.js or Python for backend. Understand databases 
        (SQL and NoSQL). Deploy projects. Timeline: 6-12 months to build strong foundation. 
        Practice by building real projects.""",
        'metadata': {'category': 'learning', 'field': 'web_development'}
    },
    {
        'id': 'skills_ai_ml_1',
        'content': """AI/ML Skills Development: Learn Python deeply. Master NumPy, Pandas, Matplotlib. 
        Study linear algebra and calculus. Learn scikit-learn for traditional ML. Progress to deep 
        learning with TensorFlow or PyTorch. Work on Kaggle competitions. Timeline: 12-18 months 
        for solid foundation.""",
        'metadata': {'category': 'skills', 'field': 'ai_ml'}
    },
]

# Add initial knowledge
try:
    knowledge_base.add_knowledge(INITIAL_KNOWLEDGE)
    print("✅ Knowledge base initialized with educational content")
except Exception as e:
    print(f"⚠️  Knowledge base already initialized or error: {e}")


def augment_prompt_with_knowledge(query: str, base_prompt: str) -> str:
    """
    Augment an AI prompt with relevant knowledge from the knowledge base.
    
    Args:
        query: User's query
        base_prompt: Original prompt to augment
        
    Returns:
        Augmented prompt with relevant context
    """
    # Search for relevant knowledge
    relevant_docs = knowledge_base.search(query, n_results=2)
    
    if not relevant_docs:
        return base_prompt
    
    # Build context from retrieved documents
    context = "\n\n**Relevant Knowledge:**\n"
    for i, doc in enumerate(relevant_docs, 1):
        context += f"\n{i}. {doc['content']}\n"
    
    # Augment prompt
    augmented_prompt = f"{context}\n\n{base_prompt}"
    
    return augmented_prompt


def collect_training_data(query: str, response: str, feedback: str = None):
    """
    Collect interaction data for future model training.
    
    Args:
        query: User's question
        response: AI's response  
        feedback: User feedback (positive/negative/rating)
    """
    # Store in a file for later processing
    data_point = {
        'query': query,
        'response': response,
        'feedback': feedback,
        'timestamp': None  # Add timestamp in production
    }
    
    # In production, store in database or data warehouse
    # For now, just log
    print(f"📊 Training data collected: {len(query)} chars")
    
    return data_point

