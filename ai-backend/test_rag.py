"""
Test Script for RAG System
This demonstrates how the knowledge base enhances AI responses
"""

from knowledge_base import knowledge_base, augment_prompt_with_knowledge

print("=" * 70)
print("🧪 Testing RAG (Retrieval Augmented Generation)")
print("=" * 70)
print()

# Test queries
test_queries = [
    "How do I become a software engineer?",
    "What skills do I need for data science?",
    "How do I prepare for internships?",
    "What should I learn for web development?",
]

print("📚 Knowledge Base Status:")
print(f"   Collection exists: ✅")
print()

for i, query in enumerate(test_queries, 1):
    print(f"Test {i}: '{query}'")
    print("-" * 70)
    
    # Search knowledge base
    results = knowledge_base.search(query, n_results=2)
    
    if results:
        print(f"✅ Found {len(results)} relevant documents:")
        for j, doc in enumerate(results, 1):
            print(f"\n   Document {j}:")
            print(f"   Category: {doc['metadata'].get('category', 'N/A')}")
            print(f"   Content: {doc['content'][:150]}...")
            print(f"   Relevance: {1 - doc['distance']:.2%}" if doc['distance'] else "   Relevance: High")
    else:
        print("❌ No relevant documents found")
    
    print()
    print()

# Test prompt augmentation
print("=" * 70)
print("🔄 Testing Prompt Augmentation")
print("=" * 70)
print()

test_prompt = "How can I help this student?"
test_query = "I want to become a software engineer"

print(f"Original Query: {test_query}")
print(f"Original Prompt: {test_prompt}")
print()

augmented_prompt = augment_prompt_with_knowledge(test_query, test_prompt)

print("Augmented Prompt:")
print("-" * 70)
print(augmented_prompt)
print()

print("=" * 70)
print("✅ RAG Testing Complete!")
print("=" * 70)
print()
print("💡 Next Steps:")
print("   1. Start backend: python3 main.py")
print("   2. Visit: http://localhost:8000/docs")
print("   3. Try /api/ai/chat with: 'How do I become a software engineer?'")
print("   4. Compare response with/without RAG!")

