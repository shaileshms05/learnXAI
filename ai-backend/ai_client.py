"""
Unified AI Client Abstraction
Supports Google AI (Gemini) as primary, Cerebras as optional fallback
"""

import os
from typing import Optional, Dict, Any, List
from openai import OpenAI
import json

# Try to import Google Generative AI (Gemini)
try:
    import google.generativeai as genai
    GOOGLE_AI_AVAILABLE = True
except ImportError:
    GOOGLE_AI_AVAILABLE = False
    genai = None

# Try to import Vertex AI (optional, for enterprise)
try:
    from vertexai.generative_models import GenerativeModel
    VERTEX_AI_AVAILABLE = True
except ImportError:
    VERTEX_AI_AVAILABLE = False
    GenerativeModel = None


class UnifiedAIClient:
    """
    Unified AI client that supports:
    1. Google AI (Gemini) - Primary
    2. Cerebras AI - Optional fallback
    """
    
    def __init__(self):
        self.provider = None
        self.google_client = None
        self.cerebras_client = None
        self.model_name = None
        self._initialize()
    
    def _initialize(self):
        """Initialize AI clients based on available API keys"""
        # Check for Google AI API key (Gemini)
        google_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        google_project = os.getenv("GOOGLE_CLOUD_PROJECT")
        google_location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
        
        # Check for Cerebras API key (optional)
        cerebras_api_key = os.getenv("CEREBRAS_API_KEY")
        
        # Priority 1: Google AI (Gemini) - Primary
        if GOOGLE_AI_AVAILABLE and google_api_key:
            try:
                genai.configure(api_key=google_api_key)
                self.google_client = genai
                self.provider = "google"
                # Use Gemini 2.5 Flash as the primary model
                self.model_name = "gemini-2.5-flash"
                print(f"✅ Using Google AI (Gemini) as primary AI provider - Model: {self.model_name}")
                return
            except Exception as e:
                print(f"⚠️  Failed to initialize Google AI: {e}")
        
        # Priority 2: Vertex AI (if project is set up)
        if VERTEX_AI_AVAILABLE and google_project:
            try:
                self.provider = "vertex"
                self.model_name = "gemini-2.5-flash"
                print(f"✅ Using Vertex AI (Gemini) as primary AI provider (Project: {google_project}) - Model: {self.model_name}")
                return
            except Exception as e:
                print(f"⚠️  Failed to initialize Vertex AI: {e}")
        
        # Priority 3: Cerebras (optional fallback)
        if cerebras_api_key:
            try:
                self.cerebras_client = OpenAI(
                    api_key=cerebras_api_key,
                    base_url="https://api.cerebras.ai/v1"
                )
                self.provider = "cerebras"
                self.model_name = "llama3.1-8b"
                print("✅ Using Cerebras AI as fallback AI provider")
                return
            except Exception as e:
                print(f"⚠️  Failed to initialize Cerebras: {e}")
        
        # No AI provider available
        raise ValueError(
            "No AI provider available. Please set one of:\n"
            "- GOOGLE_API_KEY or GEMINI_API_KEY (for Google AI)\n"
            "- GOOGLE_CLOUD_PROJECT (for Vertex AI)\n"
            "- CEREBRAS_API_KEY (optional, for Cerebras fallback)"
        )
    
    def chat_completions_create(
        self,
        model: Optional[str] = None,
        messages: List[Dict[str, str]] = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        **kwargs
    ) -> Any:
        """
        Unified interface for chat completions
        Compatible with OpenAI API format
        """
        if messages is None:
            messages = []
        
        model = model or self.model_name
        
        if self.provider == "google":
            return self._google_chat_completion(messages, temperature, max_tokens, model)
        elif self.provider == "vertex":
            return self._vertex_chat_completion(messages, temperature, max_tokens, model)
        elif self.provider == "cerebras":
            return self._cerebras_chat_completion(messages, temperature, max_tokens, model)
        else:
            raise ValueError(f"Unknown AI provider: {self.provider}")
    
    def _google_chat_completion(self, messages: List[Dict], temperature: float, max_tokens: int, model: str):
        """Google AI (Gemini) chat completion"""
        # Convert messages to Gemini format
        system_instruction = None
        conversation_history = []
        
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            
            if role == "system":
                system_instruction = content
            elif role == "user":
                conversation_history.append({"role": "user", "parts": [content]})
            elif role == "assistant":
                conversation_history.append({"role": "model", "parts": [content]})
        
        # Configure generation parameters
        generation_config = {
            "temperature": temperature,
            "max_output_tokens": max_tokens,
        }
        
        # Create model
        gemini_model = genai.GenerativeModel(
            model_name=model,
            generation_config=generation_config,
            system_instruction=system_instruction if system_instruction else None
        )
        
        # Generate response - use chat if we have history, otherwise simple generate
        if len(conversation_history) > 1:
            # Use chat interface for multi-turn conversations
            chat = gemini_model.start_chat(history=conversation_history[:-1])
            response = chat.send_message(conversation_history[-1]["parts"][0])
        else:
            # Simple generation for single message
            prompt = conversation_history[0]["parts"][0] if conversation_history else ""
            response = gemini_model.generate_content(prompt)
        
        # Extract text from response
        response_text = response.text if hasattr(response, 'text') else str(response)
        
        # Convert to OpenAI-compatible format
        class MockChoice:
            def __init__(self, text):
                self.message = MockMessage(text)
        
        class MockMessage:
            def __init__(self, text):
                self.content = text
        
        class MockResponse:
            def __init__(self, text):
                self.choices = [MockChoice(text)]
        
        return MockResponse(response_text)
    
    def _vertex_chat_completion(self, messages: List[Dict], temperature: float, max_tokens: int, model: str):
        """Vertex AI (Gemini) chat completion"""
        # Similar to Google AI but using Vertex AI SDK
        system_instruction = None
        user_messages = []
        
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            
            if role == "system":
                system_instruction = content
            elif role == "user":
                user_messages.append(content)
        
        prompt = "\n\n".join(user_messages)
        
        # Use Vertex AI GenerativeModel
        vertex_model = GenerativeModel(model_name=model)
        
        generation_config = {
            "temperature": temperature,
            "max_output_tokens": max_tokens,
        }
        
        response = vertex_model.generate_content(
            prompt,
            generation_config=generation_config,
            system_instruction=system_instruction
        )
        
        # Convert to OpenAI-compatible format
        class MockChoice:
            def __init__(self, text):
                self.message = MockMessage(text)
        
        class MockMessage:
            def __init__(self, text):
                self.content = text
        
        class MockResponse:
            def __init__(self, text):
                self.choices = [MockChoice(text)]
        
        return MockResponse(response.text)
    
    def _cerebras_chat_completion(self, messages: List[Dict], temperature: float, max_tokens: int, model: str):
        """Cerebras AI chat completion (OpenAI-compatible)"""
        return self.cerebras_client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
    
    @property
    def chat(self):
        """OpenAI-compatible chat interface"""
        class Completions:
            def __init__(self, client):
                self.client = client
            
            def create(self, **kwargs):
                return self.client.chat_completions_create(**kwargs)
        
        class ChatInterface:
            def __init__(self, client):
                self.client = client
                self.completions = Completions(client)
        
        return ChatInterface(self)

