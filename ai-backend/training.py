"""
Model Training Module for Student AI Platform

This module provides functionality to:
1. Collect training data from user interactions
2. Fine-tune models (when you have data)
3. Train custom models (advanced)
4. Evaluate model performance
"""

import json
import pandas as pd
from typing import List, Dict, Optional
from datetime import datetime
import os


class TrainingDataCollector:
    """Collects and manages training data from user interactions."""
    
    def __init__(self, data_dir="./training_data"):
        self.data_dir = data_dir
        os.makedirs(data_dir, exist_ok=True)
        self.data_file = os.path.join(data_dir, "interactions.jsonl")
        
    def log_interaction(
        self,
        user_query: str,
        ai_response: str,
        feature: str,
        user_feedback: Optional[str] = None,
        metadata: Optional[Dict] = None
    ):
        """
        Log a user-AI interaction for training purposes.
        
        Args:
            user_query: The user's input/question
            ai_response: The AI's response
            feature: Which feature (learning_path, internship, chat)
            user_feedback: User's feedback (thumbs_up, thumbs_down, rating, etc.)
            metadata: Additional context (user_profile, etc.)
        """
        interaction = {
            'timestamp': datetime.now().isoformat(),
            'user_query': user_query,
            'ai_response': ai_response,
            'feature': feature,
            'user_feedback': user_feedback,
            'metadata': metadata or {}
        }
        
        # Append to JSONL file
        with open(self.data_file, 'a') as f:
            f.write(json.dumps(interaction) + '\n')
            
        return interaction
    
    def get_training_data(
        self,
        feature: Optional[str] = None,
        min_feedback_score: Optional[float] = None
    ) -> pd.DataFrame:
        """
        Retrieve collected training data.
        
        Args:
            feature: Filter by specific feature
            min_feedback_score: Only get positively rated interactions
            
        Returns:
            DataFrame with training data
        """
        # Read JSONL file
        data = []
        if os.path.exists(self.data_file):
            with open(self.data_file, 'r') as f:
                for line in f:
                    data.append(json.loads(line))
        
        df = pd.DataFrame(data)
        
        # Apply filters
        if feature and not df.empty:
            df = df[df['feature'] == feature]
            
        return df
    
    def export_for_finetuning(self, output_file: str, format: str = 'jsonl'):
        """
        Export data in format suitable for fine-tuning.
        
        Args:
            output_file: Path to output file
            format: 'jsonl' for OpenAI, 'csv' for others
        """
        df = self.get_training_data()
        
        if format == 'jsonl':
            # OpenAI fine-tuning format
            with open(output_file, 'w') as f:
                for _, row in df.iterrows():
                    example = {
                        'messages': [
                            {'role': 'user', 'content': row['user_query']},
                            {'role': 'assistant', 'content': row['ai_response']}
                        ]
                    }
                    f.write(json.dumps(example) + '\n')
        elif format == 'csv':
            df.to_csv(output_file, index=False)
            
        print(f"✅ Exported {len(df)} training examples to {output_file}")
        return output_file


class ModelTrainer:
    """
    Handles model fine-tuning and training operations.
    """
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv('CEREBRAS_API_KEY')
        
    def finetune_cerebras(
        self,
        training_file: str,
        model: str = "llama3.1-8b",
        epochs: int = 3
    ):
        """
        Fine-tune a Cerebras model (placeholder - actual API may vary).
        
        Args:
            training_file: Path to training data (JSONL format)
            model: Base model to fine-tune
            epochs: Number of training epochs
        """
        print(f"🚀 Starting fine-tuning job...")
        print(f"   Base model: {model}")
        print(f"   Training file: {training_file}")
        print(f"   Epochs: {epochs}")
        
        # In actual implementation:
        # 1. Upload training file to Cerebras
        # 2. Start fine-tuning job
        # 3. Monitor training progress
        # 4. Get fine-tuned model ID
        
        return {
            'status': 'simulated',
            'message': 'Add your Cerebras API key to enable fine-tuning',
            'model_id': 'ft-llama3.1-8b-student-ai-v1'
        }
    
    def evaluate_model(
        self,
        model_id: str,
        test_queries: List[str]
    ) -> Dict:
        """
        Evaluate a model's performance.
        
        Args:
            model_id: ID of model to evaluate
            test_queries: List of test queries
            
        Returns:
            Evaluation metrics
        """
        print(f"📊 Evaluating model: {model_id}")
        print(f"   Test queries: {len(test_queries)}")
        
        # In actual implementation:
        # 1. Run model on test queries
        # 2. Compare with expected outputs
        # 3. Calculate metrics (accuracy, relevance, etc.)
        
        return {
            'accuracy': 0.0,
            'message': 'Collect more data to enable evaluation'
        }


# Initialize collectors
data_collector = TrainingDataCollector()
model_trainer = ModelTrainer()


def start_collecting_data():
    """
    Start collecting training data from your API endpoints.
    Call this function from your main.py endpoints.
    """
    print("✅ Training data collection enabled")
    print(f"   Data will be saved to: {data_collector.data_file}")
    print("   💡 Collect 100-1000 interactions before fine-tuning")
    

def prepare_for_finetuning(min_examples: int = 100):
    """
    Check if you have enough data and prepare for fine-tuning.
    
    Args:
        min_examples: Minimum number of examples needed
        
    Returns:
        Status and recommendations
    """
    df = data_collector.get_training_data()
    num_examples = len(df)
    
    print(f"\n📊 Training Data Status:")
    print(f"   Total interactions: {num_examples}")
    
    if num_examples < min_examples:
        print(f"   ⚠️  Need {min_examples - num_examples} more examples")
        print(f"   💡 Keep using the app to collect more data")
        return {'ready': False, 'need': min_examples - num_examples}
    else:
        print(f"   ✅ Ready for fine-tuning!")
        
        # Export data
        output_file = data_collector.export_for_finetuning(
            'training_data/finetuning_data.jsonl'
        )
        
        print(f"\n🚀 Next steps:")
        print(f"   1. Review: {output_file}")
        print(f"   2. Get Cerebras API key")
        print(f"   3. Run: model_trainer.finetune_cerebras('{output_file}')")
        
        return {'ready': True, 'file': output_file}


if __name__ == "__main__":
    # Demo: How to use the training system
    print("=" * 60)
    print("🎓 Student AI Platform - Training System")
    print("=" * 60)
    
    # Check current data status
    prepare_for_finetuning()
    
    print("\n💡 Integration Guide:")
    print("   1. Import in main.py:")
    print("      from training import data_collector")
    print("   2. Log interactions after AI responses:")
    print("      data_collector.log_interaction(query, response, 'chat')")
    print("   3. Collect 100-1000 examples")
    print("   4. Run prepare_for_finetuning()")
    print("   5. Fine-tune model")
    print("   6. Deploy improved model!")

