# MCP Internship Scraper Server

An MCP (Model Context Protocol) server that scrapes real-time internship opportunities from multiple job boards.

## Features

- **Multi-source scraping**: Scrapes from Indeed, LinkedIn, Glassdoor, and Internships.com
- **Real-time data**: Gets fresh internship listings
- **Flexible search**: Filter by query, location, and source
- **Deduplication**: Automatically removes duplicate listings
- **Structured output**: Returns JSON with all internship details
- **Primary method**: BeautifulSoup + Requests (simple, fast, reliable)
- **Fallback options**: Playwright for JavaScript-heavy sites

## Installation

```bash
cd mcp-internship-scraper
pip install -r requirements.txt

# Install Playwright browser (recommended for best performance)
playwright install chromium
```

**Note**: The scraper uses a multi-tier approach:
1. **BeautifulSoup + Requests** (primary) - Simple, fast, reliable for static HTML content
2. **Playwright** (fallback) - For JavaScript-heavy sites that require browser automation
3. **RSS Feeds** (final fallback) - When all else fails

BeautifulSoup + Requests is used first because it's:
- ✅ Fastest (no browser overhead)
- ✅ Simplest (no dependencies beyond requests/beautifulsoup4)
- ✅ Most reliable for static content
- ✅ Lower resource usage

Browser automation (Playwright/Selenium) is only used when:
- Site requires JavaScript rendering
- BeautifulSoup gets blocked (403 errors)
- Site has dynamic content loading

See [INSTALL_PLAYWRIGHT.md](INSTALL_PLAYWRIGHT.md) for Playwright setup (optional, only needed as fallback).

## Usage

### As MCP Server

The server can be used with any MCP-compatible client. Configure it in your MCP client settings:

```json
{
  "mcpServers": {
    "internship-scraper": {
      "command": "python",
      "args": ["/path/to/mcp-internship-scraper/server.py"]
    }
  }
}
```

### Available Tools

1. **search_internships**: Search across all sources
   - `query`: Search term (required)
   - `location`: Location filter (optional)
   - `max_results`: Max results per source (default: 10)
   - `sources`: List of sources to use (optional, defaults to all)

2. **scrape_indeed**: Scrape from Indeed only
3. **scrape_linkedin**: Scrape from LinkedIn only

### Example Usage

```python
# Search for software engineering internships
result = await call_tool("search_internships", {
    "query": "software engineering",
    "location": "Remote",
    "max_results": 20
})

# Search from specific sources
result = await call_tool("search_internships", {
    "query": "data science",
    "sources": ["indeed", "linkedin"],
    "max_results": 15
})
```

## Response Format

```json
{
  "success": true,
  "total_results": 25,
  "internships": [
    {
      "title": "Software Engineering Intern",
      "company": "Tech Corp",
      "location": "San Francisco, CA",
      "description": "Join our team...",
      "source": "Indeed",
      "url": "https://...",
      "scraped_at": "2024-01-03T12:00:00"
    }
  ],
  "scraped_at": "2024-01-03T12:00:00"
}
```

## Integration with Backend

To integrate with your FastAPI backend, add an endpoint:

```python
@app.post("/api/internships/scrape")
async def scrape_internships(request: ScrapeRequest):
    # Call MCP server or use scraper directly
    scraper = InternshipScraper()
    internships = scraper.scrape_all_sources(
        query=request.query,
        location=request.location,
        max_results_per_source=request.max_results
    )
    return {"internships": internships}
```

## Notes

- **Rate Limiting**: Be respectful of job board rate limits. Consider adding delays between requests.
- **LinkedIn**: LinkedIn has strict anti-scraping measures. For production, use the LinkedIn API.
- **Legal**: Ensure compliance with each site's Terms of Service and robots.txt
- **Reliability**: Web scraping can break if sites change their HTML structure. Consider using APIs when available.

## Future Enhancements

- Add more job board sources
- Implement caching to reduce requests
- Add filtering by salary, duration, etc.
- Support for authenticated scraping (LinkedIn API)
- Add webhook support for real-time updates

