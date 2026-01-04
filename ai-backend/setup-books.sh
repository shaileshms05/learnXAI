#!/bin/bash

echo "=================================================="
echo "📚 Setting up Book Learning System"
echo "=================================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install base requirements
echo "Installing base requirements..."
pip install -r requirements.txt

# Install training requirements (for RAG)
echo "Installing training requirements..."
pip install -r requirements-training.txt

# Install book processing requirements
echo "Installing book processing requirements..."
pip install -r requirements-books.txt

# Create necessary directories
echo "Creating directories..."
mkdir -p books_data/uploads
mkdir -p books_data/processed
mkdir -p books_data/progress

# Test imports
echo ""
echo "Testing imports..."
python3 << EOF
try:
    from document_processor import DocumentProcessor, BOOKS_ENABLED
    if BOOKS_ENABLED:
        print("✅ Document processor: OK")
    else:
        print("❌ Document processor: Missing dependencies")
except Exception as e:
    print(f"❌ Document processor: {e}")

try:
    from concept_extractor import ConceptExtractor
    print("✅ Concept extractor: OK")
except Exception as e:
    print(f"❌ Concept extractor: {e}")

try:
    from book_learning_system import BookLearningSystem, BOOKS_ENABLED
    if BOOKS_ENABLED:
        print("✅ Book learning system: OK")
    else:
        print("❌ Book learning system: Missing dependencies")
except Exception as e:
    print(f"❌ Book learning system: {e}")

try:
    from knowledge_base import KnowledgeBase
    print("✅ RAG system: OK")
except Exception as e:
    print(f"❌ RAG system: {e}")
EOF

echo ""
echo "=================================================="
echo "✅ Setup complete!"
echo "=================================================="
echo ""
echo "To start the server:"
echo "  python3 main.py"
echo ""
echo "To test book features:"
echo "  curl http://localhost:8000/api/books/status"
echo ""

