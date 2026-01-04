"""
Standalone Internship Scraper (without MCP dependencies)
Can be imported directly into FastAPI backend

Uses multiple scraping approaches:
1. BeautifulSoup + Requests (primary) - Simple, fast, reliable for static HTML
2. Selenium (fallback) - Browser automation for JavaScript-heavy sites
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import quote_plus, urljoin
from typing import Dict, List, Optional, TYPE_CHECKING
from datetime import datetime
import time
import re
import json

# Try to import Selenium (browser automation)
try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.chrome.service import Service
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False
    webdriver = None  # type: ignore
    Options = None  # type: ignore
    Service = None  # type: ignore

# Try to import webdriver-manager (optional, for automatic ChromeDriver management)
try:
    from webdriver_manager.chrome import ChromeDriverManager
    WEBDRIVER_MANAGER_AVAILABLE = True
except ImportError:
    WEBDRIVER_MANAGER_AVAILABLE = False
    ChromeDriverManager = None  # type: ignore


class InternshipScraper:
    """Scraper for internship opportunities from various job boards
    
    Uses multiple scraping strategies:
    - BeautifulSoup + Requests (primary) for static HTML content
    - Selenium (fallback) for JavaScript-heavy sites requiring browser automation
    """
    
    def __init__(self, use_beautifulsoup: bool = True):
        """
        Initialize scraper
        
        Args:
            use_beautifulsoup: Use BeautifulSoup + Requests as primary method (default: True)
        """
        # Enhanced headers to mimic real browser better
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
        # Browser automation tools (optional, used as fallback)
        self._driver = None  # Selenium WebDriver instance
        self._use_beautifulsoup = use_beautifulsoup
        
        self._current_query = ""
        self._current_location = ""
        
        # Primary method: BeautifulSoup + Requests (simple, fast, reliable)
        if self._use_beautifulsoup:
            print("✅ Using BeautifulSoup + Requests as primary scraping method")
        
        # Browser automation as fallback
        if SELENIUM_AVAILABLE:
            print("💡 Selenium available - will use as fallback for JavaScript-heavy sites")
        else:
            print("💡 Selenium not available - install with: pip install selenium webdriver-manager")
    
    def _get_driver(self):
        """Get or create Selenium WebDriver"""
        if not SELENIUM_AVAILABLE:
            return None
        
        if self._driver is None:
            try:
                chrome_options = Options()
                chrome_options.add_argument('--headless')  # Run in background
                chrome_options.add_argument('--no-sandbox')
                chrome_options.add_argument('--disable-dev-shm-usage')
                chrome_options.add_argument('--disable-blink-features=AutomationControlled')
                chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
                chrome_options.add_experimental_option('useAutomationExtension', False)
                chrome_options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
                
                # Check if webdriver-manager is available (with safety check)
                use_webdriver_manager = False
                try:
                    use_webdriver_manager = WEBDRIVER_MANAGER_AVAILABLE
                except NameError:
                    # Variable not defined, assume webdriver-manager is not available
                    use_webdriver_manager = False
                
                if use_webdriver_manager:
                    try:
                        service = Service(ChromeDriverManager().install())
                        self._driver = webdriver.Chrome(service=service, options=chrome_options)
                    except Exception as e:
                        print(f"⚠️  WebDriver Manager failed, trying system ChromeDriver: {e}")
                        self._driver = webdriver.Chrome(options=chrome_options)
                else:
                    # Try to use system ChromeDriver
                    self._driver = webdriver.Chrome(options=chrome_options)
                
                # Execute script to hide webdriver property
                self._driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
                    'source': 'Object.defineProperty(navigator, "webdriver", {get: () => undefined})'
                })
                
                print("✅ Selenium WebDriver initialized")
            except Exception as e:
                print(f"⚠️  Failed to initialize Selenium: {e}")
                print("💡 Install ChromeDriver or use: pip install webdriver-manager")
                return None
        
        return self._driver
    
    def _scrape_with_selenium(self, url: str, wait_selector: Optional[str] = None, timeout: int = 30) -> Optional[str]:
        """Scrape a URL using Selenium"""
        if not SELENIUM_AVAILABLE:
            print("⚠️  Selenium not available")
            return None
        
        driver = self._get_driver()
        if not driver:
            return None
        
        try:
            print(f"🌐 Selenium navigating to: {url}")
            # Set longer timeouts for slow-loading pages
            driver.set_page_load_timeout(timeout)
            driver.set_script_timeout(timeout)
            
            # Try to load the page with retry logic
            max_retries = 2
            for attempt in range(max_retries):
                try:
                    driver.get(url)
                    break
                except Exception as e:
                    if attempt < max_retries - 1:
                        print(f"⚠️  Page load attempt {attempt + 1} failed, retrying...")
                        time.sleep(2)
                    else:
                        # On final attempt, try to get page source even if load timed out
                        print(f"⚠️  Page load timeout, attempting to get page source anyway...")
                        try:
                            # Try to get current page source even if load didn't complete
                            page_source = driver.page_source
                            if page_source and len(page_source) > 1000:
                                print(f"📄 Retrieved partial page source ({len(page_source)} chars)")
                                return page_source
                        except:
                            pass
                        raise e
            
            # Wait for page to be in a ready state
            try:
                WebDriverWait(driver, min(10, timeout // 3)).until(
                    lambda d: d.execute_script("return document.readyState") == "complete"
                )
            except:
                print("⚠️  Page ready state check timeout, continuing anyway...")
            
            # Wait for page to load or specific selector (with shorter timeout)
            if wait_selector:
                try:
                    # Try each selector in the comma-separated list with shorter timeout
                    selectors = [s.strip() for s in wait_selector.split(',')]
                    found = False
                    wait_timeout = min(15, timeout // 2)  # Use shorter timeout for selector wait
                    for selector in selectors:
                        try:
                            WebDriverWait(driver, wait_timeout).until(
                                EC.presence_of_element_located((By.CSS_SELECTOR, selector))
                            )
                            print(f"✅ Selenium found selector: {selector}")
                            found = True
                            break
                        except:
                            continue
                    if not found:
                        print(f"⚠️  Selenium timeout waiting for selectors: {wait_selector} (page may still have loaded)")
                except Exception as e:
                    print(f"⚠️  Selenium timeout waiting for selector {wait_selector}: {e}")
                    # Continue anyway, page might have loaded
            
            # Wait a bit for dynamic content to render
            time.sleep(3)
            
            # Scroll to trigger lazy loading
            try:
                driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(1)
                driver.execute_script("window.scrollTo(0, 0);")
                time.sleep(1)
            except:
                pass
            
            page_source = driver.page_source
            print(f"📄 Selenium retrieved {len(page_source)} characters of HTML")
            return page_source
        except Exception as e:
            print(f"⚠️  Selenium scraping failed: {e}")
            # Try to get page source even on error
            try:
                page_source = driver.page_source
                if page_source and len(page_source) > 1000:
                    print(f"📄 Retrieved page source despite error ({len(page_source)} chars)")
                    return page_source
            except:
                pass
            import traceback
            traceback.print_exc()
            return None
    
    def __del__(self):
        """Cleanup browser automation tools"""
        # Cleanup Selenium WebDriver
        if self._driver:
            try:
                self._driver.quit()
            except Exception:
                pass
        
        # Selenium removed - no cleanup needed
    
    def _get_indeed_domain_and_location(self, location: str) -> tuple[str, str]:
        """Determine which Indeed domain to use and format location"""
        indian_cities = {
            'bangalore': 'Bengaluru, Karnataka',
            'banglore': 'Bengaluru, Karnataka',
            'bengaluru': 'Bengaluru, Karnataka',
            'bangaluru': 'Bengaluru, Karnataka',
            'mumbai': 'Mumbai, Maharashtra',
            'delhi': 'Delhi, Delhi',
            'hyderabad': 'Hyderabad, Telangana',
            'chennai': 'Chennai, Tamil Nadu',
            'pune': 'Pune, Maharashtra',
            'coimbatore': 'Coimbatore, Tamil Nadu',
        }
        
        loc_lower = location.lower().strip() if location else ""
        
        # Check if it's an Indian city
        for city_key, formatted_location in indian_cities.items():
            if city_key in loc_lower:
                return 'in.indeed.com', formatted_location
        
        # Default to US Indeed
        return 'www.indeed.com', location.strip() if location else ""
    
    def scrape_indeed_rss(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Try to scrape using Indeed RSS feed (more reliable)"""
        internships = []
        try:
            # Build search query similar to main scraper
            query_clean = query.strip().lower()
            if 'intern' not in query_clean and 'internship' not in query_clean:
                search_query = f"{query} intern"
            else:
                search_query = query
            
            # Determine which Indeed domain to use (India vs US)
            indeed_domain, formatted_location = self._get_indeed_domain_and_location(location)
            
            # Build RSS URL - India Indeed might not support RSS, but try anyway
            if indeed_domain == 'in.indeed.com':
                query_param = quote_plus(search_query, safe=' ')
                if formatted_location:
                    location_param = quote_plus(formatted_location, safe=' ')
                    rss_url = f"https://{indeed_domain}/rss?q={query_param}&l={location_param}"
                else:
                    rss_url = f"https://{indeed_domain}/rss?q={query_param}"
            else:
                rss_url = f"https://{indeed_domain}/rss?q={quote_plus(search_query)}&l={quote_plus(formatted_location) if formatted_location else ''}&jt=internship"
            
            print(f"🌐 Trying Indeed RSS: {rss_url}")
            response = self.session.get(rss_url, timeout=15)
            
            if response.status_code == 200 and 'xml' in response.headers.get('content-type', '').lower():
                from xml.etree import ElementTree as ET
                root = ET.fromstring(response.content)
                
                # Parse RSS items
                for item in root.findall('.//item')[:max_results]:
                    try:
                        title = item.find('title')
                        link = item.find('link')
                        description = item.find('description')
                        
                        if title is not None and title.text:
                            # Parse title (format: "Job Title - Company - Location")
                            title_parts = title.text.split(' - ')
                            job_title = title_parts[0].strip()
                            company = title_parts[1].strip() if len(title_parts) > 1 else "Company Not Specified"
                            location_text = title_parts[2].strip() if len(title_parts) > 2 else location or "Location Not Specified"
                            
                            job_desc = description.text if description is not None and description.text else f"Internship opportunity for {query}"
                            
                            # Filter for relevance
                            if self._is_relevant(job_title, job_desc, location_text, query, location):
                                internships.append({
                                    'title': job_title,
                                    'company': company,
                                    'location': location_text,
                                    'description': job_desc,
                                    'source': 'Indeed (RSS)',
                                    'url': link.text if link is not None and link.text else '',
                                    'scraped_at': datetime.now().isoformat()
                                })
                                print(f"  ✅ Found via RSS: {job_title} at {company} ({location_text})")
                            else:
                                print(f"  ⏭️  Skipped RSS (not relevant): {job_title}")
                    except Exception as e:
                        print(f"  ⚠️  Error parsing RSS item: {e}")
                        continue
                
                if internships:
                    # Score and sort by relevance
                    scored_internships = []
                    for job in internships:
                        score = self._calculate_relevance_score(
                            job['title'],
                            job.get('description', ''),
                            job['location'],
                            query,
                            location
                        )
                        scored_internships.append((score, job))
                    
                    scored_internships.sort(key=lambda x: x[0], reverse=True)
                    internships = [job for _, job in scored_internships[:max_results]]
                    print(f"📊 RSS scraping successful: {len(internships)} relevant internships found")
                    return internships
        except Exception as e:
            print(f"⚠️  RSS scraping failed: {e}")
        
        return []
    
    def scrape_indeed(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from Indeed using BeautifulSoup + Requests, with Selenium as fallback"""
        internships = []
        
        # Determine which Indeed domain to use (India vs US)
        indeed_domain, formatted_location = self._get_indeed_domain_and_location(location)
        
        # Build search query - India Indeed doesn't use jt=internship parameter
        query_clean = query.strip().lower()
        if indeed_domain == 'in.indeed.com':
            # For India: include "intern" in query itself, don't use jt parameter
            if 'intern' not in query_clean and 'internship' not in query_clean:
                search_query = f"{query} intern"
            else:
                search_query = query
        else:
            # For US: can use jt=internship parameter
            if 'intern' not in query_clean and 'internship' not in query_clean:
                search_query = f"{query} intern"
            else:
                search_query = query
        
        # Build URL - Indeed India uses different format
        if indeed_domain == 'in.indeed.com':
            # India Indeed format: q=software+engineer&l=Bengaluru%2C+Karnataka
            # Match the exact format from working URL (uses + for spaces, not %20)
            query_param = quote_plus(search_query)  # Encode spaces as +
            if formatted_location:
                location_param = quote_plus(formatted_location)  # Encode spaces as +
                url = f"https://{indeed_domain}/jobs?q={query_param}&l={location_param}"
            else:
                url = f"https://{indeed_domain}/jobs?q={query_param}"
        else:
            # US Indeed format: q=software+engineer+intern&jt=internship&l=location
            params = {
                'q': search_query,
                'jt': 'internship',  # Filter to internships only
            }
            if formatted_location:
                params['l'] = formatted_location
            url = f"https://{indeed_domain}/jobs?" + "&".join([f"{k}={quote_plus(v)}" for k, v in params.items()])
        
        # Store original query for filtering
        self._current_query = query.lower()
        self._current_location = location.lower() if location else ""
        
        print(f"🌐 Scraping Indeed ({indeed_domain}): {url}")
        
        # Strategy 1: Try BeautifulSoup + Requests first (simplest, fastest for static content)
        try:
            print("🚀 Using BeautifulSoup + Requests...")
            # Add delay to be respectful
            time.sleep(1)
            
            # Enhanced headers to mimic real browser
            enhanced_headers = self.headers.copy()
            enhanced_headers.update({
                'Referer': f'https://{indeed_domain}/',
                'Origin': f'https://{indeed_domain}',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
            })
            
            response = self.session.get(url, headers=enhanced_headers, timeout=25, allow_redirects=True)
            print(f"📊 Indeed response status: {response.status_code}")
            
            if response.status_code == 200:
                # Check if we got redirected to a captcha or error page
                if 'captcha' in response.url.lower() or 'unusual' in response.text.lower()[:1000]:
                    print("🚫 Indeed is showing captcha or blocking request")
                else:
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    # Debug: Check if page has job listings
                    page_text = soup.get_text().lower()
                    if 'no jobs found' in page_text or 'try different keywords' in page_text:
                        print("⚠️  Indeed shows 'no jobs found' message")
                    else:
                        # Parse HTML
                        internships = self._parse_indeed_html(soup, query, location, max_results * 2)
                        
                        # Filter and sort by relevance
                        if internships:
                            # Score each internship
                            scored_internships = []
                            for job in internships:
                                score = self._calculate_relevance_score(
                                    job['title'], 
                                    job.get('description', ''),
                                    job['location'],
                                    query,
                                    location
                                )
                                scored_internships.append((score, job))
                            
                            # Filter out low-scoring jobs (adaptive filtering)
                            if scored_internships:
                                max_score = max(s for s, _ in scored_internships)
                                if len(scored_internships) <= 5:
                                    min_score = 0.15
                                elif max_score > 0.4:
                                    min_score = 0.2
                                else:
                                    min_score = 0.25
                            else:
                                min_score = 0.2 if location else 0.15
                            
                            filtered_scored = [(s, j) for s, j in scored_internships if s >= min_score]
                            
                            # If filtering removed everything, be more lenient
                            if not filtered_scored and scored_internships:
                                filtered_scored = sorted(scored_internships, key=lambda x: x[0], reverse=True)[:max_results]
                                print(f"⚠️  All jobs below threshold, returning top {len(filtered_scored)} anyway")
                            
                            # Sort by relevance score
                            filtered_scored.sort(key=lambda x: x[0], reverse=True)
                            internships = [job for _, job in filtered_scored[:max_results]]
                            
                            # Log results
                            filtered_count = len(internships)
                            total_count = len(scored_internships)
                            print(f"📊 Filtered {total_count} jobs → {filtered_count} relevant internships")
                            
                            if location and internships:
                                matching_locations = [j['location'] for _, j in internships]
                                print(f"📍 Locations found: {', '.join(set(matching_locations[:5]))}")
                            
                            if internships:
                                print(f"✅ BeautifulSoup scraping successful: {len(internships)} internships found")
                                return internships
                        
                        print("⚠️  BeautifulSoup found page but no jobs parsed - trying browser automation...")
            elif response.status_code == 403:
                print("🚫 Access forbidden (403) - trying browser automation...")
            else:
                print(f"⚠️  Unexpected status code {response.status_code} - trying browser automation...")
        except Exception as e:
            print(f"⚠️  BeautifulSoup scraping failed: {e}")
            # Fallback to browser automation
        
        # Strategy 2: Try Selenium (for JavaScript-heavy sites)
        if SELENIUM_AVAILABLE:
            try:
                print("🚀 Using Selenium to bypass Cloudflare...")
                page_source = self._scrape_with_selenium(
                    url,
                    wait_selector="[data-jk], .job_seen_beacon, .jobCard",
                    timeout=30
                )
                
                if page_source:
                    print(f"📄 Selenium retrieved {len(page_source)} characters of HTML")
                    soup = BeautifulSoup(page_source, 'html.parser')
                    internships = self._parse_indeed_html(soup, query, location, max_results * 2)
                    
                    if internships:
                        print(f"✅ Selenium scraping successful: {len(internships)} internships found")
                        return internships
                    else:
                        print("⚠️  Selenium retrieved page but no jobs were parsed")
                else:
                    print("⚠️  Selenium returned no page source")
            except Exception as e:
                print(f"⚠️  Selenium scraping failed: {e}")
            import traceback
            traceback.print_exc()
        else:
            print("⏭️  Selenium not available")
        
        # Final fallback: Try RSS feed
        print("🔄 Trying RSS feed as final fallback...")
        try:
            rss_results = self.scrape_indeed_rss(query, location, max_results)
            if rss_results:
                return rss_results
        except Exception as e:
            print(f"⚠️  RSS feed failed: {e}")
        
        return internships
    
    def _parse_indeed_html(self, soup: BeautifulSoup, query: str, location: str, max_results: int) -> List[Dict]:
        """Parse Indeed HTML to extract job listings"""
        internships = []
        
        # Method 1: Look for job cards with data-jk attribute (job key)
        job_cards = soup.find_all('div', {'data-jk': True})
        if not job_cards:
            # Method 2: Look for job_seen_beacon class
            job_cards = soup.find_all('div', class_='job_seen_beacon')
        if not job_cards:
            # Method 3: Look for job cards by structure
            job_cards = soup.find_all('div', class_=re.compile(r'job.*card|card.*job', re.I))
        if not job_cards:
            # Method 4: Look for any div with job-related classes
            job_cards = soup.find_all('div', class_=lambda x: x and ('job' in ' '.join(x).lower() or 'result' in ' '.join(x).lower()))
        
        print(f"📋 Found {len(job_cards)} potential job cards on Indeed")
        
        # Process found job cards
        for card in job_cards[:max_results]:
            try:
                # Extract job key for link
                job_key = card.get('data-jk', '')
                
                # Find title - try multiple selectors (including India Indeed specific)
                title_elem = (
                    card.find('h2', class_='jobTitle') or
                    card.find('h2', class_=re.compile(r'title', re.I)) or
                    card.find('a', class_='jobTitle') or
                    card.find('a', class_=re.compile(r'job.*title|title.*job', re.I)) or
                    card.find('span', {'id': lambda x: x and 'jobTitle' in x.lower()}) or
                    card.find('span', class_=re.compile(r'title', re.I)) or
                    card.find('h2', {'data-testid': lambda x: x and 'title' in x.lower()}) or
                    card.find('a', {'data-testid': lambda x: x and 'title' in x.lower()}) or
                    card.find('h2') or
                    card.find('h3') or
                    card.find('a', href=re.compile(r'/viewjob|/jobs', re.I))  # Link to job page often has title
                )
                
                # Find company
                company_elem = (
                    card.find('span', class_='companyName') or
                    card.find('span', {'data-testid': 'company-name'}) or
                    card.find('a', class_='companyName') or
                    card.find('span', class_=re.compile(r'company', re.I))
                )
                
                # Find location
                location_elem = (
                    card.find('div', class_='companyLocation') or
                    card.find('div', {'data-testid': 'job-location'}) or
                    card.find('span', class_='companyLocation') or
                    card.find('div', class_=re.compile(r'location', re.I))
                )
                
                # Find summary - try multiple selectors
                summary_elem = (
                    card.find('div', class_='job-snippet') or
                    card.find('div', class_='summary') or
                    card.find('span', class_='summary') or
                    card.find('div', class_=re.compile(r'snippet|summary|description', re.I)) or
                    card.find('span', class_=re.compile(r'snippet|summary|description', re.I)) or
                    card.find('div', {'data-testid': lambda x: x and ('snippet' in x.lower() or 'summary' in x.lower())}) or
                    card.find('ul', class_=re.compile(r'job.*requirement|requirement', re.I))  # Sometimes requirements are shown
                )
                
                if title_elem:
                    # Get title text - try to get from nested elements if main element is too short
                    title = title_elem.get_text(strip=True)
                    
                    # If title is too short or generic, try to find nested link or span with better text
                    if not title or len(title) < 5 or title.lower() in ['intern', 'internship', 'job']:
                        # Try to find nested link with title
                        nested_link = title_elem.find('a', href=True)
                        if nested_link:
                            nested_title = nested_link.get_text(strip=True)
                            if nested_title and len(nested_title) > len(title):
                                title = nested_title
                        
                        # Try to find nested span
                        nested_span = title_elem.find('span')
                        if nested_span:
                            nested_title = nested_span.get_text(strip=True)
                            if nested_title and len(nested_title) > len(title):
                                title = nested_title
                        
                        # If still too short, try to get all text from the card's title area
                        if not title or len(title) < 5:
                            # Look for any text in the card that might be the title
                            all_text = card.get_text(separator=' ', strip=True)
                            # Try to extract meaningful title from first line
                            first_line = all_text.split('\n')[0] if '\n' in all_text else all_text.split('.')[0]
                            if first_line and len(first_line) > len(title):
                                title = first_line[:100]  # Limit length
                    
                    if not title or len(title) < 3:
                        continue
                        
                    company = company_elem.get_text(strip=True) if company_elem else "Company Not Specified"
                    location_text = location_elem.get_text(strip=True) if location_elem else location or "Location Not Specified"
                    
                    # Extract summary - try to get more context if summary is missing or too short
                    summary = summary_elem.get_text(strip=True) if summary_elem else ""
                    
                    # If summary is missing or too short, try to extract more context from the card
                    if not summary or len(summary) < 20:
                        # Get all text from card and remove title, company, location to get description
                        all_card_text = card.get_text(separator=' ', strip=True)
                        # Remove title, company, location from the text to get description
                        text_parts = all_card_text.split()
                        title_words = set(title.lower().split())
                        company_words = set(company.lower().split())
                        location_words = set(location_text.lower().split())
                        
                        # Filter out title, company, location words to get description
                        desc_words = [w for w in text_parts if w.lower() not in title_words and w.lower() not in company_words and w.lower() not in location_words]
                        if desc_words:
                            summary = ' '.join(desc_words[:50])  # Take first 50 words
                    
                    # Fallback if still no summary
                    if not summary or len(summary) < 10:
                        summary = f"Internship opportunity for {query} position"
                    
                    # Build job link
                    job_link = ""
                    if job_key:
                        # Determine domain from current context
                        indeed_domain = 'in.indeed.com' if self._current_location and any(city in self._current_location for city in ['bangalore', 'banglore', 'mumbai', 'delhi', 'hyderabad', 'chennai', 'pune', 'coimbatore']) else 'www.indeed.com'
                        job_link = f"https://{indeed_domain}/viewjob?jk={job_key}"
                    else:
                        link_elem = title_elem.find('a') if title_elem.name != 'a' else title_elem
                        if not link_elem or link_elem.name != 'a':
                            link_elem = card.find('a', href=True)
                        
                        if link_elem and link_elem.get('href'):
                            href = link_elem['href']
                            if href.startswith('/'):
                                # Determine domain from current context
                                indeed_domain = 'in.indeed.com' if self._current_location and any(city in self._current_location for city in ['bangalore', 'banglore', 'mumbai', 'delhi', 'hyderabad', 'chennai', 'pune', 'coimbatore']) else 'www.indeed.com'
                                job_link = f"https://{indeed_domain}{href}"
                            elif href.startswith('http'):
                                job_link = href
                    
                    # Filter for relevance
                    if self._is_relevant(title, summary, location_text, query, location):
                        internships.append({
                            'title': title,
                            'company': company,
                            'location': location_text,
                            'description': summary,
                            'source': 'Indeed',
                            'url': job_link,
                            'scraped_at': datetime.now().isoformat()
                        })
                        print(f"  ✅ Found: {title} at {company} ({location_text})")
                    else:
                        print(f"  ⏭️  Skipped (not relevant): {title}")
            except Exception as e:
                print(f"  ⚠️  Error parsing Indeed job card: {e}")
                continue
        
        # Remove duplicates
        seen_titles = set()
        unique_internships = []
        for job in internships:
            title_lower = job['title'].lower()
            if title_lower not in seen_titles:
                seen_titles.add(title_lower)
                unique_internships.append(job)
        
        return unique_internships
    
    def _calculate_relevance_score(self, title: str, description: str, job_location: str, query: str, location: str) -> float:
        """Calculate relevance score (0-1) for a job listing"""
        title_lower = title.lower()
        desc_lower = description.lower()
        job_loc_lower = job_location.lower()
        query_lower = query.lower()
        loc_lower = location.lower() if location else ""
        
        score = 0.0
        
        # Base score for internships (ensures internships get some points even if query terms don't match)
        is_internship = (
            'intern' in title_lower or 
            'internship' in title_lower or 
            'intern' in desc_lower or 
            'internship' in desc_lower or
            'camp' in title_lower or
            'trainee' in title_lower
        )
        if is_internship:
            score += 0.15  # Base score for any internship
        
        # Extract key terms from query (remove common words)
        stop_words = {'intern', 'internship', 'the', 'a', 'an', 'and', 'or', 'in', 'at', 'for', 'of', 'to'}
        # Don't remove 'engineer' and 'developer' from stop words - they're important query terms
        query_terms = [term for term in query_lower.split() if term not in stop_words and len(term) > 2]
        
        # Tech-related keywords that indicate relevance to software engineering
        tech_keywords = {
            'software': ['software', 'developer', 'programming', 'code', 'coding', 'application', 'app', 'web', 'mobile', 'backend', 'frontend', 'fullstack', 'full-stack'],
            'engineer': ['engineer', 'engineering', 'developer', 'programmer', 'coder', 'architect', 'technical'],
            'test': ['test', 'testing', 'qa', 'quality', 'automation', 'sdet'],
            'ai': ['ai', 'artificial intelligence', 'machine learning', 'ml', 'data science', 'data scientist'],
            'data': ['data', 'analyst', 'analytics', 'database', 'data engineer'],
        }
        
        # Check if query is about software engineering
        is_software_query = any(term in query_lower for term in ['software', 'developer', 'engineer', 'programming'])
        
        # Title matching (most important)
        title_matches = sum(1 for term in query_terms if term in title_lower)
        if query_terms:
            score += (title_matches / len(query_terms)) * 0.5
        
        # Bonus: If it's a software engineering query, accept related tech roles
        if is_software_query:
            # Check for engineering/developer roles
            if any(keyword in title_lower for keyword in ['engineer', 'developer', 'programmer', 'coder']):
                score += 0.2  # Bonus for engineering roles
            # Check for related tech fields (QA, Test, AI, etc. are still relevant)
            if any(keyword in title_lower for keyword in ['test', 'qa', 'quality', 'automation', 'ai', 'machine learning', 'data']):
                score += 0.15  # Bonus for related tech fields
        
        # Description matching
        title_desc = f"{title_lower} {desc_lower}"
        desc_matches = sum(1 for term in query_terms if term in title_desc)
        if query_terms:
            score += (desc_matches / len(query_terms)) * 0.2
        
        # Location matching (strict)
        if loc_lower:
            location_variations = {
                'remote': ['remote', 'work from home', 'wfh', 'anywhere', 'work from anywhere', 'work remotely'],
                'bangalore': ['bangalore', 'bengaluru', 'bangaluru', 'banglore', 'bangalore, india', 'bengaluru, india', 'banglore, india'],  # Added misspelling
                'mumbai': ['mumbai', 'bombay', 'mumbai, india', 'bombay, india'],
                'delhi': ['delhi', 'ncr', 'new delhi', 'gurgaon', 'gurugram', 'noida', 'delhi, india', 'new delhi, india'],
                'hyderabad': ['hyderabad', 'hyderabad, india'],
                'chennai': ['chennai', 'madras', 'chennai, india', 'madras, india'],
                'pune': ['pune', 'pune, india'],
                'coimbatore': ['coimbatore', 'coimbatore, india'],
                'india': ['india', 'indian'],
            }
            
            matched = False
            job_loc_lower_clean = job_loc_lower.replace(',', '').replace('.', '')
            
            # Check for exact location match
            for key, variations in location_variations.items():
                if key in loc_lower:
                    # Check if job location contains any variation
                    if any(var in job_loc_lower_clean for var in variations):
                        score += 0.4  # Strong location match
                        matched = True
                        break
            
            # If location specified but doesn't match
            if not matched:
                # Check if it's a US location when searching for Indian city
                us_indicators = ['ca', 'co', 'ny', 'tx', 'il', 'pa', 'ut', 'md', 'al', 'wa', 'or', 'az', 'fl', 'ma', 'nc', 'united states', 'usa', 'us', 'united states of america']
                indian_cities = ['bangalore', 'banglore', 'mumbai', 'delhi', 'hyderabad', 'chennai', 'pune', 'coimbatore']
                
                # Normalize location for comparison
                loc_normalized = loc_lower.replace('bangalore', 'bangalore').replace('banglore', 'bangalore')
                
                if any(ind in loc_normalized for ind in indian_cities):
                    # Searching for Indian city
                    if any(us_ind in job_loc_lower_clean for us_ind in us_indicators):
                        # Job is in US, searching for India - heavily penalize but don't completely exclude
                        # If query matches well, still include but with low score
                        if score > 0.3:  # Query matches well
                            score *= 0.15  # Reduce but don't eliminate
                        else:
                            score *= 0.05  # Very low score
                    else:
                        # Not US, but also not matching Indian city - moderate penalty
                        score *= 0.4
                else:
                    # Location doesn't match at all (but not US vs India mismatch)
                    score *= 0.5
        else:
            # No location specified, don't penalize
            score += 0.1
        
        return score
    
    def _is_relevant(self, title: str, description: str, job_location: str, query: str, location: str) -> bool:
        """Check if a job listing is relevant to the search query and location"""
        title_lower = title.lower()
        desc_lower = description.lower()
        query_lower = query.lower()
        
        # Check if it's an internship (be lenient - check title, description, or common patterns)
        is_internship = (
            'intern' in title_lower or 
            'internship' in title_lower or 
            'intern' in desc_lower or 
            'internship' in desc_lower or
            'camp' in title_lower or  # "Internship Camp" is a common pattern
            'trainee' in title_lower
        )
        
        # Special case: if title is just "Intern" or very generic, check description more carefully
        is_generic_title = title_lower.strip() in ['intern', 'internship', 'job', 'position'] or len(title_lower.strip()) < 5
        
        if not is_internship:
            return False  # Not an internship
        
        # For generic titles like "Intern", be more lenient if description exists and contains relevant terms
        if is_generic_title and description and len(description) > 20:
            # Check if description contains query terms or internship-related terms
            desc_has_query = any(term in desc_lower for term in query_lower.split() if len(term) > 3)
            desc_has_tech = any(term in desc_lower for term in ['software', 'developer', 'engineer', 'programming', 'code', 'technical', 'tech'])
            if desc_has_query or desc_has_tech:
                # Very lenient for generic titles with relevant descriptions
                score = self._calculate_relevance_score(title, description, job_location, query, location)
                return score >= 0.1  # Very low threshold
        
        # Check if it's a general internship program/camp (more lenient matching)
        is_general_internship = (
            'camp' in title_lower or
            'program' in title_lower or
            'winter' in title_lower or
            'summer' in title_lower
        )
        
        # Use the scoring function for consistency
        score = self._calculate_relevance_score(title, description, job_location, query, location)
        
        # Relevance threshold - be more lenient, especially for internships
        loc_lower = location.lower() if location else ""
        
        # Extract query terms for better matching
        stop_words = {'intern', 'internship', 'the', 'a', 'an', 'and', 'or', 'in', 'at', 'for', 'of', 'to'}
        query_terms = [term for term in query_lower.split() if term not in stop_words and len(term) > 2]
        
        # Check if title contains any query terms
        title_has_query_terms = any(term in title_lower for term in query_terms) if query_terms else True
        
        # Also check for related tech roles (QA, Test, AI, etc. are relevant to software engineering)
        is_software_query = any(term in query_lower for term in ['software', 'developer', 'engineer', 'programming'])
        is_tech_role = any(keyword in title_lower for keyword in ['engineer', 'developer', 'programmer', 'test', 'qa', 'automation', 'ai', 'machine learning', 'data'])
        
        # If query is about software engineering and job is a tech role, consider it relevant
        if is_software_query and is_tech_role:
            title_has_query_terms = True  # Override to consider it relevant
        
        # For general internship programs/camps, be very lenient if location matches
        if is_general_internship:
            if loc_lower:
                # For general programs, accept if location matches reasonably well
                job_loc_lower = job_location.lower() if job_location else ""
                location_keywords = ['bangalore', 'bengaluru', 'banglore', 'india', 'karnataka']
                location_matches = any(keyword in job_loc_lower for keyword in location_keywords) if loc_lower and any(city in loc_lower for city in ['bangalore', 'bengaluru', 'banglore']) else True
                
                if location_matches:
                    return score >= 0.1  # Very lenient for general programs with location match
                else:
                    return score >= 0.15  # Still lenient even without location match
            else:
                return score >= 0.1  # Very lenient for general programs without location
        
        if loc_lower:
            # Location specified - be lenient if query matches or it's clearly an internship
            # For tech roles, be even more lenient
            if is_software_query and is_tech_role:
                return score >= 0.15  # Very lenient for tech roles
            elif title_has_query_terms or score > 0.2:
                return score >= 0.2  # Lower threshold when query matches
            else:
                return score >= 0.25  # Slightly lower threshold for internships
        else:
            # No location specified - be very lenient
            if is_software_query and is_tech_role:
                return score >= 0.1  # Very lenient for tech roles without location
            return score >= 0.15
    
    def scrape_linkedin(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from LinkedIn (using search API simulation)"""
        internships = []
        try:
            # LinkedIn requires authentication and has strict anti-scraping
            # For now, return empty and let fallback handle it
            # In production, use LinkedIn API: https://www.linkedin.com/developers/
            print("⚠️  LinkedIn scraping requires API access. Skipping...")
            print("💡 Tip: Use LinkedIn API for production. See: https://www.linkedin.com/developers/")
            return internships
            
        except Exception as e:
            print(f"❌ Error scraping LinkedIn: {e}")
        
        return internships
    
    def scrape_glassdoor(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape internships from Glassdoor"""
        internships = []
        try:
            search_query = f"{query} intern internship"
            if location:
                search_query += f" {location}"
            
            url = f"https://www.glassdoor.com/Job/jobs.htm?sc.keyword={quote_plus(search_query)}&jobType=internship"
            
            print(f"🌐 Scraping Glassdoor: {url}")
            response = requests.get(url, headers=self.headers, timeout=15)
            print(f"📊 Glassdoor response status: {response.status_code}")
            
            if response.status_code != 200:
                print(f"⚠️  Glassdoor returned status {response.status_code}")
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Try multiple selectors for Glassdoor
            job_cards = soup.find_all('li', class_='react-job-listing')
            if not job_cards:
                job_cards = soup.find_all('div', {'data-test': 'job-listing'})
            if not job_cards:
                job_cards = soup.find_all('li', {'data-test': 'job-listing'})
            
            print(f"📋 Found {len(job_cards)} job cards on Glassdoor")
            job_cards = job_cards[:max_results]
            
            for card in job_cards:
                try:
                    # Try multiple selectors
                    title_elem = card.find('a', {'data-test': 'job-link'}) or card.find('a', class_='jobLink')
                    company_elem = card.find('div', class_='d-flex') or card.find('span', {'data-test': 'employer-name'})
                    location_elem = card.find('span', class_='css-1buaf54') or card.find('span', {'data-test': 'job-location'})
                    
                    if title_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True) if company_elem else "Company Not Specified"
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Location Not Specified"
                        
                        job_link = ""
                        if title_elem.get('href'):
                            href = title_elem['href']
                            if href.startswith('/'):
                                job_link = f"https://www.glassdoor.com{href}"
                            elif href.startswith('http'):
                                job_link = href
                        
                        if title:
                            internships.append({
                                'title': title,
                                'company': company,
                                'location': location_text,
                                'description': f"Internship opportunity at {company}",
                                'source': 'Glassdoor',
                                'url': job_link,
                                'scraped_at': datetime.now().isoformat()
                            })
                            print(f"  ✅ Found: {title} at {company}")
                except Exception as e:
                    print(f"  ⚠️  Error parsing Glassdoor job: {e}")
                    continue
                    
        except Exception as e:
            print(f"❌ Error scraping Glassdoor: {e}")
        
        print(f"📊 Glassdoor scraping complete: {len(internships)} internships found")
        return internships
    
    def scrape_internships_com(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape from Internships.com"""
        internships = []
        try:
            url = f"https://www.internships.com/search?q={quote_plus(query)}"
            if location:
                url += f"&location={quote_plus(location)}"
            
            print(f"🌐 Scraping Internships.com: {url}")
            response = requests.get(url, headers=self.headers, timeout=15)
            print(f"📊 Internships.com response status: {response.status_code}")
            
            if response.status_code != 200:
                print(f"⚠️  Internships.com returned status {response.status_code}")
                return internships
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Try multiple selectors
            job_cards = soup.find_all('div', class_='internship')
            if not job_cards:
                job_cards = soup.find_all('div', {'data-internship-id': True})
            if not job_cards:
                job_cards = soup.find_all('article', class_='internship')
            
            print(f"📋 Found {len(job_cards)} job cards on Internships.com")
            job_cards = job_cards[:max_results]
            
            for card in job_cards:
                try:
                    # Try multiple selectors
                    title_elem = card.find('h3', class_='title') or card.find('h2') or card.find('a', class_='title')
                    company_elem = card.find('div', class_='company') or card.find('span', class_='company')
                    location_elem = card.find('div', class_='location') or card.find('span', class_='location')
                    link_elem = card.find('a', href=True)
                    
                    if title_elem:
                        title = title_elem.get_text(strip=True)
                        company = company_elem.get_text(strip=True) if company_elem else "Company Not Specified"
                        location_text = location_elem.get_text(strip=True) if location_elem else location or "Location Not Specified"
                        
                        job_link = ""
                        if link_elem and link_elem.get('href'):
                            href = link_elem['href']
                            if href.startswith('/'):
                                job_link = f"https://www.internships.com{href}"
                            elif href.startswith('http'):
                                job_link = href
                        
                        if title:
                            internships.append({
                                'title': title,
                                'company': company,
                                'location': location_text,
                                'description': f"Internship opportunity at {company}",
                                'source': 'Internships.com',
                                'url': job_link,
                                'scraped_at': datetime.now().isoformat()
                            })
                            print(f"  ✅ Found: {title} at {company}")
                except Exception as e:
                    print(f"  ⚠️  Error parsing Internships.com job: {e}")
                    continue
                    
        except Exception as e:
            print(f"❌ Error scraping Internships.com: {e}")
        
        print(f"📊 Internships.com scraping complete: {len(internships)} internships found")
        return internships
    
    def scrape_skill_india(self, query: str, location: str = "", max_results: int = 20) -> List[Dict]:
        """Scrape from Skill India Digital (skillindiadigital.gov.in)"""
        internships = []
        try:
            # Skill India Digital is an Angular app, requires browser automation
            url = "https://www.skillindiadigital.gov.in/internship"
            print(f"🌐 Scraping Skill India Digital: {url}")
            
            # Use Selenium for browser automation (with longer timeout for Angular apps)
            page_source = None
            if SELENIUM_AVAILABLE:
                try:
                    print("🚀 Using Selenium for Skill India Digital...")
                    # Use longer timeout for Skill India Digital (Angular app takes time to load)
                    page_source = self._scrape_with_selenium(
                        url,
                        wait_selector="mat-card, .internship-card, [class*='card'], app-root",
                        timeout=60  # Increased timeout for Skill India Digital
                    )
                except Exception as e:
                    print(f"⚠️  Selenium failed for Skill India: {e}")
                    # Try one more time with even more lenient settings
                    try:
                        print("🔄 Retrying Skill India Digital with minimal wait...")
                        page_source = self._scrape_with_selenium(
                            url,
                            wait_selector=None,  # Don't wait for specific selector
                            timeout=45
                        )
                    except Exception as retry_e:
                        print(f"⚠️  Retry also failed: {retry_e}")
            
            if not page_source:
                print("⚠️  Could not load Skill India Digital page (requires browser automation)")
                return internships
            
            soup = BeautifulSoup(page_source, 'html.parser')
            
            # Try multiple selectors for internship cards
            # Angular Material cards or custom cards
            job_cards = soup.find_all('mat-card')
            if not job_cards:
                job_cards = soup.find_all('div', class_=re.compile(r'card|internship', re.I))
            if not job_cards:
                job_cards = soup.find_all('article')
            if not job_cards:
                # Look for any element with internship-related classes
                job_cards = soup.find_all('div', class_=lambda x: x and ('internship' in ' '.join(x).lower() or 'course' in ' '.join(x).lower()))
            
            print(f"📋 Found {len(job_cards)} potential internship cards on Skill India Digital")
            job_cards = job_cards[:max_results]
            
            for card in job_cards:
                try:
                    # Try to find title - multiple selectors
                    title_elem = (
                        card.find('h2') or
                        card.find('h3') or
                        card.find('h4') or
                        card.find('mat-card-title') or
                        card.find('div', class_=re.compile(r'title|heading', re.I)) or
                        card.find('a', class_=re.compile(r'title', re.I))
                    )
                    
                    if not title_elem:
                        # Try to get text from the card
                        all_text = card.get_text(separator=' ', strip=True)
                        if len(all_text) > 20:  # If card has substantial text
                            title = all_text.split('\n')[0][:100] if '\n' in all_text else all_text[:100]
                        else:
                            continue
                    else:
                        title = title_elem.get_text(strip=True)
                    
                    if not title or len(title) < 5:
                        continue
                    
                    # Try to find provider/company
                    company_elem = (
                        card.find('div', class_=re.compile(r'provider|company|organization', re.I)) or
                        card.find('span', class_=re.compile(r'provider|company', re.I)) or
                        card.find('mat-card-subtitle')
                    )
                    company = company_elem.get_text(strip=True) if company_elem else "Skill India Digital"
                    
                    # Try to find location
                    location_elem = (
                        card.find('div', class_=re.compile(r'location|place', re.I)) or
                        card.find('span', class_=re.compile(r'location', re.I))
                    )
                    location_text = location_elem.get_text(strip=True) if location_elem else location or "India"
                    
                    # Try to find link
                    link_elem = card.find('a', href=True)
                    job_link = ""
                    if link_elem and link_elem.get('href'):
                        href = link_elem['href']
                        if href.startswith('/'):
                            job_link = f"https://www.skillindiadigital.gov.in{href}"
                        elif href.startswith('http'):
                            job_link = href
                    else:
                        job_link = url
                    
                    # Try to find description
                    desc_elem = (
                        card.find('p') or
                        card.find('div', class_=re.compile(r'description|summary|content', re.I)) or
                        card.find('mat-card-content')
                    )
                    description = desc_elem.get_text(strip=True) if desc_elem else f"Internship opportunity: {title}"
                    
                    # Check if it's paid or free
                    paid_elem = card.find(string=re.compile(r'paid|free', re.I))
                    fee_info = paid_elem.strip() if paid_elem else ""
                    
                    internships.append({
                        'title': title,
                        'company': company,
                        'location': location_text,
                        'description': description[:500] if description else f"Internship opportunity: {title}",
                        'source': 'Skill India Digital',
                        'url': job_link,
                        'scraped_at': datetime.now().isoformat()
                    })
                    print(f"  ✅ Found: {title} at {company}")
                except Exception as e:
                    print(f"  ⚠️  Error parsing Skill India job: {e}")
                    continue
                    
        except Exception as e:
            print(f"❌ Error scraping Skill India Digital: {e}")
            import traceback
            traceback.print_exc()
        
        print(f"📊 Skill India Digital scraping complete: {len(internships)} internships found")
        return internships
    
    def scrape_all_sources(self, query: str, location: str = "", max_results_per_source: int = 10) -> List[Dict]:
        """Scrape from all available sources"""
        all_internships = []
        
        sources = [
            ('Indeed', self.scrape_indeed),
            ('LinkedIn', self.scrape_linkedin),
            ('Glassdoor', self.scrape_glassdoor),
            ('Internships.com', self.scrape_internships_com),
            ('Skill India Digital', self.scrape_skill_india),
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
    
    def generate_sample_internships(self, query: str, location: str = "", count: int = 10) -> List[Dict]:
        """Generate sample internships when scraping fails (fallback)"""
        # Tech companies known for internships
        tech_companies = [
            {"name": "Google", "domain": "google.com"},
            {"name": "Microsoft", "domain": "microsoft.com"},
            {"name": "Amazon", "domain": "amazon.jobs"},
            {"name": "Meta", "domain": "meta.com"},
            {"name": "Apple", "domain": "apple.com"},
            {"name": "Netflix", "domain": "jobs.netflix.com"},
            {"name": "Uber", "domain": "uber.com"},
            {"name": "Airbnb", "domain": "airbnb.com"},
            {"name": "Stripe", "domain": "stripe.com"},
            {"name": "Salesforce", "domain": "salesforce.com"},
            {"name": "Adobe", "domain": "adobe.com"},
            {"name": "Oracle", "domain": "oracle.com"},
            {"name": "IBM", "domain": "ibm.com"},
            {"name": "Intel", "domain": "intel.com"},
            {"name": "NVIDIA", "domain": "nvidia.com"},
            {"name": "Tesla", "domain": "tesla.com"},
            {"name": "Spotify", "domain": "spotify.com"},
            {"name": "GitHub", "domain": "github.com"},
            {"name": "MongoDB", "domain": "mongodb.com"},
            {"name": "Databricks", "domain": "databricks.com"},
        ]
        
        # Generate varied titles based on query
        query_lower = query.lower()
        if "data" in query_lower or "science" in query_lower:
            title_templates = [
                "Data Science Intern",
                "Machine Learning Intern",
                "Data Engineering Intern",
                "AI/ML Intern",
                "Analytics Intern"
            ]
        elif "software" in query_lower or "engineer" in query_lower:
            title_templates = [
                "Software Engineering Intern",
                "Full Stack Intern",
                "Backend Engineering Intern",
                "Frontend Engineering Intern",
                "DevOps Intern"
            ]
        else:
            title_templates = [
                f"{query.title()} Intern",
                f"Summer {query.title()} Intern",
                f"{query.title()} Internship Program",
                f"Engineering Intern ({query})",
            ]
        
        internships = []
        for i in range(min(count, len(tech_companies))):
            company_info = tech_companies[i]
            company = company_info["name"]
            title = title_templates[i % len(title_templates)]
            
            # Generate realistic descriptions
            descriptions = [
                f"Join {company} as a {title} and work on cutting-edge projects. Gain hands-on experience with industry-leading technologies and collaborate with world-class engineers.",
                f"Exciting {title} opportunity at {company}. Work on real-world projects, receive mentorship from senior engineers, and contribute to products used by millions.",
                f"{company} is seeking a {title} to join our team. You'll work on innovative projects, learn from experts, and make a real impact.",
            ]
            
            internships.append({
                'title': title,
                'company': company,
                'location': location or "Remote / Hybrid / On-site",
                'description': descriptions[i % len(descriptions)],
                'source': 'Sample',
                'url': f"https://{company_info['domain']}/careers",
                'scraped_at': datetime.now().isoformat()
            })
        
        return internships

