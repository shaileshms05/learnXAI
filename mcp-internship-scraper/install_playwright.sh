#!/bin/bash

# Install Playwright for enhanced web scraping
echo "🚀 Installing Playwright for enhanced web scraping..."

# Install Playwright Python package
echo "📦 Installing Playwright Python package..."
pip install playwright

# Install Chromium browser
echo "🌐 Installing Chromium browser..."
playwright install chromium

echo "✅ Playwright installation complete!"
echo ""
echo "To verify installation, run:"
echo "  python -c 'from playwright.sync_api import sync_playwright; print(\"✅ Playwright is installed\")'"

