#!/usr/bin/env python3
"""
MCP Server for Real-Time Internship Opportunity Scraping
Provides tools to scrape internships from various job boards
"""

import asyncio
import json
import sys
from typing import Any, Dict, List, Optional
from datetime import datetime
import re

try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import Tool, TextContent
except ImportError:
    print("MCP SDK not installed. Install with: pip install mcp")
    sys.exit(1)

import requests
from bs4 import BeautifulSoup
from urllib.parse import quote_plus

# Initialize MCP Server
server = Server("internship-scraper")


class InternshipScraper:
    """Scraper for internship opportunities from various job boards"""
    
    def __init__(self):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
    
    def scrape_indeed(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from Indeed"""
        internships = []
        try:
            # Indeed search URL
            search_query = f"{query} intern internship"
            if location:
                search_query += f" {location}"
            
            url = f"https://www.indeed.com/jobs?q={quote_plus(search_query)}&jt=internship&start=0"
            
            response = requests.get(url, headers=self.headers, timeout=10)
            if response.status_code != 200:
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find job listings (Indeed's structure)
            job_cards = soup.find_all('div', class_='job_seen_beacon')[:max_results]
            
            for card in job_cards:
                try:
                    title_elem = card.find('h2', class_='jobTitle')
                    company_elem = card.find('span', class_='companyName')
                    location_elem = card.find('div', class_='companyLocation')
                    summary_elem = card.find('div', class_='job-snippet')
                    
                    if title_elem and company_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True)
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Not specified"
                        summary = summary_elem.get_text(strip=True) if summary_elem else ""
                        
                        # Get job link
                        link_elem = title_elem.find('a')
                        job_link = f"https://www.indeed.com{link_elem['href']}" if link_elem and link_elem.get('href') else ""
                        
                        internships.append({
                            'title': title,
                            'company': company,
                            'location': location_text,
                            'description': summary,
                            'source': 'Indeed',
                            'url': job_link,
                            'scraped_at': datetime.now().isoformat()
                        })
                except Exception as e:
                    print(f"Error parsing Indeed job: {e}")
                    continue
                    
        except Exception as e:
            print(f"Error scraping Indeed: {e}")
        
        return internships
    
    def scrape_linkedin(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from LinkedIn (using search API simulation)"""
        internships = []
        try:
            # LinkedIn requires authentication, so we'll use a simplified approach
            # In production, use LinkedIn API or authenticated scraping
            search_query = f"{query} intern internship"
            if location:
                search_query += f" {location}"
            
            # Note: LinkedIn has strict anti-scraping measures
            # This is a placeholder - in production, use LinkedIn API
            url = f"https://www.linkedin.com/jobs/search/?keywords={quote_plus(search_query)}&f_JT=I&position=1&pageNum=0"
            
            response = requests.get(url, headers=self.headers, timeout=10)
            if response.status_code != 200:
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # LinkedIn job cards structure
            job_cards = soup.find_all('div', class_='base-card')[:max_results]
            
            for card in job_cards:
                try:
                    title_elem = card.find('h3', class_='base-search-card__title')
                    company_elem = card.find('h4', class_='base-search-card__subtitle')
                    location_elem = card.find('span', class_='job-search-card__location')
                    link_elem = card.find('a', class_='base-card__full-link')
                    
                    if title_elem and company_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True)
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Not specified"
                        job_link = link_elem['href'] if link_elem and link_elem.get('href') else ""
                        
                        internships.append({
                            'title': title,
                            'company': company,
                            'location': location_text,
                            'description': '',
                            'source': 'LinkedIn',
                            'url': job_link,
                            'scraped_at': datetime.now().isoformat()
                        })
                except Exception as e:
                    print(f"Error parsing LinkedIn job: {e}")
                    continue
                    
        except Exception as e:
            print(f"Error scraping LinkedIn: {e}")
        
        return internships
    
    def scrape_glassdoor(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from Glassdoor"""
        internships = []
        try:
            search_query = f"{query} intern internship"
            if location:
                search_query += f" {location}"
            
            url = f"https://www.glassdoor.com/Job/jobs.htm?sc.keyword={quote_plus(search_query)}&jobType=internship"
            
            response = requests.get(url, headers=self.headers, timeout=10)
            if response.status_code != 200:
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Glassdoor job listings
            job_cards = soup.find_all('li', class_='react-job-listing')[:max_results]
            
            for card in job_cards:
                try:
                    title_elem = card.find('a', {'data-test': 'job-link'})
                    company_elem = card.find('div', class_='d-flex')
                    location_elem = card.find('span', class_='css-1buaf54')
                    
                    if title_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True) if company_elem else "Not specified"
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Not specified"
                        job_link = f"https://www.glassdoor.com{title_elem['href']}" if title_elem.get('href') else ""
                        
                        internships.append({
                            'title': title,
                            'company': company,
                            'location': location_text,
                            'description': '',
                            'source': 'Glassdoor',
                            'url': job_link,
                            'scraped_at': datetime.now().isoformat()
                        })
                except Exception as e:
                    print(f"Error parsing Glassdoor job: {e}")
                    continue
                    
        except Exception as e:
            print(f"Error scraping Glassdoor: {e}")
        
        return internships
    
    def scrape_internships_com(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape from Internships.com"""
        internships = []
        try:
            search_query = query.replace(' ', '-')
            url = f"https://www.internships.com/search?q={quote_plus(query)}"
            
            response = requests.get(url, headers=self.headers, timeout=10)
            if response.status_code != 200:
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find internship listings
            job_cards = soup.find_all('div', class_='internship')[:max_results]
            
            for card in job_cards:
                try:
                    title_elem = card.find('h3', class_='title')
                    company_elem = card.find('div', class_='company')
                    location_elem = card.find('div', class_='location')
                    link_elem = card.find('a')
                    
                    if title_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True) if company_elem else "Not specified"
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Not specified"
                        job_link = link_elem['href'] if link_elem and link_elem.get('href') else ""
                        
                        internships.append({
                            'title': title,
                            'company': company,
                            'location': location_text,
                            'description': '',
                            'source': 'Internships.com',
                            'url': job_link,
                            'scraped_at': datetime.now().isoformat()
                        })
                except Exception as e:
                    print(f"Error parsing Internships.com job: {e}")
                    continue
                    
        except Exception as e:
            print(f"Error scraping Internships.com: {e}")
        
        return internships
    
    def scrape_all_sources(self, query: str, location: str = "", max_results_per_source: int = 10) -> List[Dict]:
        """Scrape from all available sources"""
        all_internships = []
        
        sources = [
            ('Indeed', self.scrape_indeed),
            ('LinkedIn', self.scrape_linkedin),
            ('Glassdoor', self.scrape_glassdoor),
            ('Internships.com', self.scrape_internships_com),
        ]
        
        for source_name, scraper_func in sources:
            try:
                internships = scraper_func(query, location, max_results_per_source)
                all_internships.extend(internships)
                print(f"Scraped {len(internships)} internships from {source_name}")
            except Exception as e:
                print(f"Error scraping {source_name}: {e}")
                continue
        
        # Remove duplicates based on title and company
        seen = set()
        unique_internships = []
        for internship in all_internships:
            key = (internship['title'].lower(), internship['company'].lower())
            if key not in seen:
                seen.add(key)
                unique_internships.append(internship)
        
        return unique_internships


# Initialize scraper
scraper = InternshipScraper()


@server.list_tools()
async def list_tools() -> List[Tool]:
    """List available tools"""
    return [
        Tool(
            name="search_internships",
            description="Search for internship opportunities from multiple job boards (Indeed, LinkedIn, Glassdoor, Internships.com)",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query (e.g., 'software engineering', 'data science', 'marketing')"
                    },
                    "location": {
                        "type": "string",
                        "description": "Location filter (e.g., 'Remote', 'San Francisco', 'New York'). Leave empty for all locations.",
                        "default": ""
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of results per source (default: 10)",
                        "default": 10
                    },
                    "sources": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of sources to scrape from: 'indeed', 'linkedin', 'glassdoor', 'internships.com'. Leave empty for all sources.",
                        "default": []
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="scrape_indeed",
            description="Scrape internships specifically from Indeed",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query"
                    },
                    "location": {
                        "type": "string",
                        "description": "Location filter",
                        "default": ""
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of results",
                        "default": 20
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="scrape_linkedin",
            description="Scrape internships specifically from LinkedIn",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query"
                    },
                    "location": {
                        "type": "string",
                        "description": "Location filter",
                        "default": ""
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum number of results",
                        "default": 20
                    }
                },
                "required": ["query"]
            }
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle tool calls"""
    try:
        if name == "search_internships":
            query = arguments.get("query", "")
            location = arguments.get("location", "")
            max_results = arguments.get("max_results", 10)
            sources = arguments.get("sources", [])
            
            if not query:
                return [TextContent(
                    type="text",
                    text=json.dumps({"error": "Query is required"}, indent=2)
                )]
            
            all_internships = []
            
            if not sources or "indeed" in sources:
                all_internships.extend(scraper.scrape_indeed(query, location, max_results))
            
            if not sources or "linkedin" in sources:
                all_internships.extend(scraper.scrape_linkedin(query, location, max_results))
            
            if not sources or "glassdoor" in sources:
                all_internships.extend(scraper.scrape_glassdoor(query, location, max_results))
            
            if not sources or "internships.com" in sources:
                all_internships.extend(scraper.scrape_internships_com(query, location, max_results))
            
            # Remove duplicates
            seen = set()
            unique_internships = []
            for internship in all_internships:
                key = (internship['title'].lower(), internship['company'].lower())
                if key not in seen:
                    seen.add(key)
                    unique_internships.append(internship)
            
            result = {
                "success": True,
                "total_results": len(unique_internships),
                "internships": unique_internships,
                "scraped_at": datetime.now().isoformat()
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        elif name == "scrape_indeed":
            query = arguments.get("query", "")
            location = arguments.get("location", "")
            max_results = arguments.get("max_results", 20)
            
            internships = scraper.scrape_indeed(query, location, max_results)
            
            result = {
                "success": True,
                "source": "Indeed",
                "total_results": len(internships),
                "internships": internships
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        elif name == "scrape_linkedin":
            query = arguments.get("query", "")
            location = arguments.get("location", "")
            max_results = arguments.get("max_results", 20)
            
            internships = scraper.scrape_linkedin(query, location, max_results)
            
            result = {
                "success": True,
                "source": "LinkedIn",
                "total_results": len(internships),
                "internships": internships
            }
            
            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]
        
        else:
            return [TextContent(
                type="text",
                text=json.dumps({"error": f"Unknown tool: {name}"}, indent=2)
            )]
    
    except Exception as e:
        return [TextContent(
            type="text",
            text=json.dumps({"error": str(e)}, indent=2)
        )]


async def main():
    """Main entry point"""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())

