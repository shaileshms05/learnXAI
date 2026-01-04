"""
Integration script to use the internship scraper with FastAPI backend
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from server import InternshipScraper
import json

def scrape_internships_for_backend(query: str, location: str = "", max_results: int = 20):
    """
    Scrape internships and return in format compatible with backend API
    
    Args:
        query: Search query (e.g., "software engineering")
        location: Location filter (e.g., "Remote", "San Francisco")
        max_results: Maximum results per source
    
    Returns:
        List of internship dictionaries
    """
    scraper = InternshipScraper()
    internships = scraper.scrape_all_sources(query, location, max_results)
    
    # Format for backend compatibility
    formatted = []
    for internship in internships:
        formatted.append({
            'title': internship['title'],
            'company': internship['company'],
            'description': internship.get('description', ''),
            'location': internship['location'],
            'type': 'Internship',
            'duration': 'Not specified',
            'requiredSkills': [],  # Could be extracted from description
            'benefits': [],
            'applicationTips': f"Apply via {internship['source']}",
            'matchScore': 75,  # Default score
            'url': internship.get('url', ''),
            'source': internship['source'],
            'scraped_at': internship.get('scraped_at', '')
        })
    
    return formatted


if __name__ == "__main__":
    # Test the scraper
    print("Testing internship scraper...")
    results = scrape_internships_for_backend("software engineering", "Remote", 5)
    print(f"\nFound {len(results)} internships:")
    for i, internship in enumerate(results[:3], 1):
        print(f"\n{i}. {internship['title']} at {internship['company']}")
        print(f"   Location: {internship['location']}")
        print(f"   Source: {internship['source']}")

