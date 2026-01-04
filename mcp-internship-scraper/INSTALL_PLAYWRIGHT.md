# Installing Playwright for Enhanced Web Scraping

The scraper now uses **Playwright** as the primary browser automation tool, with Selenium as a fallback. Playwright is faster, more reliable, and better at handling modern JavaScript-heavy websites.

## Quick Installation

```bash
# Install Playwright Python package
pip install playwright

# Install Chromium browser (required for Playwright)
playwright install chromium
```

## Why Playwright?

- **Faster**: Generally 2-3x faster than Selenium
- **More Reliable**: Better handling of modern JavaScript frameworks
- **Better Anti-Detection**: More effective at bypassing bot detection
- **Modern API**: Cleaner, more intuitive API
- **Auto-waiting**: Automatically waits for elements to be ready

## Installation Options

### Option 1: Full Installation (Recommended)
```bash
pip install playwright
playwright install chromium
```

### Option 2: Install All Browsers
```bash
pip install playwright
playwright install  # Installs Chromium, Firefox, and WebKit
```

### Option 3: System Dependencies (Linux)
```bash
# Ubuntu/Debian
sudo apt-get install -y libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2

# Then install Playwright
pip install playwright
playwright install chromium
```

## Fallback Behavior

If Playwright is not installed, the scraper will automatically fall back to:
1. **Selenium** (if available)
2. **Requests + BeautifulSoup** (for static content)

## Verification

After installation, test the scraper:

```python
from scraper import InternshipScraper

scraper = InternshipScraper()
# Should print: "✅ Playwright browser initialized"
results = scraper.scrape_indeed("software engineer", "Remote", 5)
print(f"Found {len(results)} internships")
```

## Troubleshooting

### Playwright not found
```
⚠️  Failed to initialize Playwright: ...
💡 Install Playwright: pip install playwright && playwright install chromium
```
**Solution**: Run `pip install playwright && playwright install chromium`

### Browser not found
```
⚠️  Failed to initialize Playwright: Executable doesn't exist
```
**Solution**: Run `playwright install chromium`

### Permission errors (Linux/Mac)
```bash
# Make sure playwright browsers are executable
chmod +x ~/.cache/ms-playwright/chromium-*/chrome-linux/chrome
```

## Performance Comparison

| Method | Speed | Reliability | Anti-Detection |
|--------|-------|-------------|----------------|
| Playwright | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Selenium | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Requests | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐ |

## Notes

- Playwright requires ~150MB disk space for Chromium
- First run may be slower as it downloads the browser
- Works best with headless mode (default)
- Automatically handles JavaScript rendering

