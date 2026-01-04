# MCP Internship Scraper Setup Guide

## Quick Start

1. **Install Dependencies**
   ```bash
   cd mcp-internship-scraper
   pip install -r requirements.txt
   ```

2. **Install Playwright Browser (Recommended)**
   ```bash
   # Playwright is the preferred browser automation tool (faster, more reliable)
   playwright install chromium
   ```
   
   **Note**: Playwright is optional and only used as a fallback when BeautifulSoup + Requests gets blocked. See [INSTALL_PLAYWRIGHT.md](INSTALL_PLAYWRIGHT.md) for details.

2. **Test the Scraper**
   ```bash
   python integration.py
   ```

3. **Use as MCP Server**
   ```bash
   python server.py
   ```

## Integration with FastAPI Backend

The backend endpoint `/api/internships/scrape` is already configured to use this scraper.

### Example API Call

```bash
curl -X POST "http://localhost:8000/api/internships/scrape" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "software engineering",
    "location": "Remote",
    "max_results": 20,
    "sources": ["indeed", "linkedin"]
  }'
```

### Response Format

```json
{
  "success": true,
  "total_results": 15,
  "opportunities": [
    {
      "title": "Software Engineering Intern",
      "company": "Tech Corp",
      "description": "...",
      "location": "Remote",
      "type": "Internship",
      "duration": "Not specified",
      "requiredSkills": [],
      "benefits": [],
      "applicationTips": "Apply via Indeed",
      "matchScore": 75,
      "url": "https://...",
      "source": "Indeed",
      "scraped_at": "2024-01-03T12:00:00"
    }
  ]
}
```

## Integration with Flutter App

Update `ai_service.dart` to add a new method:

```dart
Future<List<Internship>> scrapeInternships({
  required String query,
  String location = "",
  int maxResults = 20,
  List<String> sources = const [],
}) async {
  try {
    final data = await _makeRequest('/internships/scrape', {
      'query': query,
      'location': location,
      'max_results': maxResults,
      'sources': sources,
    });

    if (data != null && data['opportunities'] != null) {
      return (data['opportunities'] as List)
          .map((opportunity) => Internship(
                company: opportunity['company'] ?? '',
                role: opportunity['title'] ?? '',
                description: opportunity['description'] ?? '',
                requirements: List<String>.from(opportunity['requiredSkills'] ?? []),
                location: opportunity['location'] ?? '',
                duration: opportunity['duration'] ?? 'Not specified',
              ))
          .toList();
    }
    return [];
  } catch (e) {
    print('Error scraping internships: $e');
    return [];
  }
}
```

## Configuration

### Rate Limiting

To avoid being blocked, add delays between requests:

```python
import time

# In scraper methods, add:
time.sleep(1)  # 1 second delay between requests
```

### User Agent

Update the User-Agent in `server.py` if needed:

```python
self.headers = {
    'User-Agent': 'Your-App-Name/1.0 (Contact: your@email.com)'
}
```

## Troubleshooting

### Import Errors

If you get import errors, ensure all dependencies are installed:
```bash
pip install mcp requests beautifulsoup4 lxml
```

### No Results

- Check your internet connection
- Verify the job board URLs are accessible
- Some sites may block automated requests (use proxies or APIs)

### LinkedIn Issues

LinkedIn has strict anti-scraping measures. For production:
- Use LinkedIn API (requires authentication)
- Consider using a service like ScraperAPI
- Or focus on other sources

## Legal Considerations

- **Respect robots.txt**: Check each site's robots.txt before scraping
- **Terms of Service**: Review each site's ToS
- **Rate Limiting**: Don't overload servers with requests
- **Attribution**: Credit sources when displaying results

## Production Recommendations

1. **Use APIs when available**: LinkedIn, Indeed, etc. have official APIs
2. **Add caching**: Cache results to reduce requests
3. **Use proxies**: Rotate IPs to avoid blocks
4. **Add retry logic**: Handle temporary failures gracefully
5. **Monitor**: Track success rates and errors

