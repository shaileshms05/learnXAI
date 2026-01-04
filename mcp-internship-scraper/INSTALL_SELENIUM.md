# Installing Selenium for Real Web Scraping

The scraper now uses **Selenium** with Chrome to bypass Cloudflare protection and actually scrape job listings.

## Quick Install

```bash
# Install Python packages
pip install selenium webdriver-manager

# Or if using the backend requirements
pip install -r ../ai-backend/requirements.txt
```

## What Selenium Does

- Uses a **real Chrome browser** (headless mode)
- Bypasses Cloudflare protection (403 errors)
- Renders JavaScript-heavy pages
- Gets actual job listings from Indeed, Glassdoor, etc.

## How It Works

1. **First attempt**: Uses Selenium with Chrome to load pages (bypasses Cloudflare)
2. **Fallback**: If Selenium fails, tries RSS feeds
3. **Last resort**: Returns empty results (no fake data)

## Requirements

- **Chrome browser** must be installed on your system
- **ChromeDriver** will be automatically downloaded by `webdriver-manager`

## Testing

After installing, restart your backend and try scraping:

```bash
# Test endpoint
curl http://localhost:8000/api/internships/scrape/test
```

You should see:
- `✅ Selenium WebDriver initialized`
- `🚀 Using Selenium WebDriver to bypass Cloudflare...`
- Actual job listings!

## Troubleshooting

### "ChromeDriver not found"
- `webdriver-manager` should auto-download it
- Or install manually: https://chromedriver.chromium.org/

### "Chrome browser not found"
- Install Google Chrome: https://www.google.com/chrome/
- Or use Firefox with GeckoDriver

### Still getting 403 errors?
- Selenium should bypass this, but if not:
  - Check your IP isn't blocked
  - Try adding delays between requests
  - Consider using a proxy service

## Notes

- Selenium is slower than requests (takes 3-5 seconds per page)
- Uses more resources (runs a browser)
- But it actually works! 🎉

