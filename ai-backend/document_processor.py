"""
Document Processing Module for "Upload → Learn → Master" Feature

Handles PDF, EPUB, DOCX parsing and text extraction
"""

import os
import io
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
import re

try:
    import PyPDF2
    import pdfplumber
    from docx import Document
    import ebooklib
    from ebooklib import epub
    from bs4 import BeautifulSoup
    BOOKS_ENABLED = True
except ImportError:
    BOOKS_ENABLED = False
    print("⚠️  Book processing libraries not installed. Run: pip install -r requirements-books.txt")


@dataclass
class Chapter:
    """Represents a book chapter"""
    number: int
    title: str
    content: str
    sections: List[str]
    page_start: Optional[int] = None
    page_end: Optional[int] = None


@dataclass
class BookMetadata:
    """Book metadata"""
    title: str
    author: Optional[str] = None
    total_pages: Optional[int] = None
    total_chapters: int = 0
    language: str = "en"


class DocumentProcessor:
    """Processes various document formats"""
    
    def __init__(self):
        if not BOOKS_ENABLED:
            raise ImportError("Book processing libraries not installed")
    
    def process_document(self, file_path: str, file_type: str) -> Tuple[BookMetadata, List[Chapter]]:
        """
        Process a document and extract chapters
        
        Args:
            file_path: Path to the document
            file_type: Type of document (pdf, epub, docx)
            
        Returns:
            Tuple of (metadata, chapters)
        """
        if file_type.lower() == 'pdf':
            return self._process_pdf(file_path)
        elif file_type.lower() == 'epub':
            return self._process_epub(file_path)
        elif file_type.lower() in ['docx', 'doc']:
            return self._process_docx(file_path)
        else:
            raise ValueError(f"Unsupported file type: {file_type}")
    
    def _process_pdf(self, file_path: str) -> Tuple[BookMetadata, List[Chapter]]:
        """Process PDF file"""
        chapters = []
        
        # Extract text using pdfplumber (better formatting)
        with pdfplumber.open(file_path) as pdf:
            total_pages = len(pdf.pages)
            full_text = ""
            
            for page in pdf.pages:
                text = page.extract_text()
                if text:
                    full_text += text + "\n\n"
            
            # Extract metadata
            metadata = BookMetadata(
                title=pdf.metadata.get('Title', 'Unknown'),
                author=pdf.metadata.get('Author', 'Unknown'),
                total_pages=total_pages
            )
            
            # Split into chapters (heuristic-based)
            chapters = self._extract_chapters(full_text)
            metadata.total_chapters = len(chapters)
        
        return metadata, chapters
    
    def _process_epub(self, file_path: str) -> Tuple[BookMetadata, List[Chapter]]:
        """Process EPUB file"""
        book = epub.read_epub(file_path)
        chapters = []
        
        # Extract metadata
        metadata = BookMetadata(
            title=book.get_metadata('DC', 'title')[0][0] if book.get_metadata('DC', 'title') else 'Unknown',
            author=book.get_metadata('DC', 'creator')[0][0] if book.get_metadata('DC', 'creator') else 'Unknown'
        )
        
        chapter_num = 0
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_DOCUMENT:
                soup = BeautifulSoup(item.get_content(), 'html.parser')
                text = soup.get_text()
                
                if len(text.strip()) > 100:  # Only substantial content
                    chapter_num += 1
                    
                    # Try to extract chapter title
                    title = "Chapter " + str(chapter_num)
                    h1 = soup.find('h1')
                    if h1:
                        title = h1.get_text().strip()
                    
                    chapters.append(Chapter(
                        number=chapter_num,
                        title=title,
                        content=text.strip(),
                        sections=self._extract_sections(text)
                    ))
        
        metadata.total_chapters = len(chapters)
        return metadata, chapters
    
    def _process_docx(self, file_path: str) -> Tuple[BookMetadata, List[Chapter]]:
        """Process DOCX file"""
        doc = Document(file_path)
        
        # Extract metadata
        core_props = doc.core_properties
        metadata = BookMetadata(
            title=core_props.title or 'Unknown',
            author=core_props.author or 'Unknown'
        )
        
        # Extract full text
        full_text = "\n\n".join([para.text for para in doc.paragraphs if para.text.strip()])
        
        # Split into chapters
        chapters = self._extract_chapters(full_text)
        metadata.total_chapters = len(chapters)
        
        return metadata, chapters
    
    def _extract_chapters(self, text: str) -> List[Chapter]:
        """
        Extract chapters from text using heuristics
        Looks for patterns like:
        - "Chapter 1", "CHAPTER ONE", "1. Introduction"
        - Major section headings
        """
        chapters = []
        
        # Pattern to detect chapter headings
        chapter_pattern = r'(?:^|\n)(?:Chapter|CHAPTER|Ch\.|Section)\s+(\d+|[IVX]+|One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten)[:\.\s]+([^\n]+)'
        
        matches = list(re.finditer(chapter_pattern, text, re.MULTILINE | re.IGNORECASE))
        
        if not matches:
            # No clear chapters found, treat as single chapter
            return [Chapter(
                number=1,
                title="Full Document",
                content=text,
                sections=self._extract_sections(text)
            )]
        
        for i, match in enumerate(matches):
            chapter_num = self._normalize_chapter_number(match.group(1))
            chapter_title = match.group(2).strip()
            
            # Extract content between this chapter and next
            start_pos = match.end()
            end_pos = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            content = text[start_pos:end_pos].strip()
            
            chapters.append(Chapter(
                number=chapter_num,
                title=chapter_title,
                content=content,
                sections=self._extract_sections(content)
            ))
        
        return chapters
    
    def _extract_sections(self, text: str) -> List[str]:
        """Extract section headings from text"""
        sections = []
        
        # Look for numbered sections or bold headings
        section_pattern = r'(?:^|\n)(\d+\.\d+|\d+\.)\s+([^\n]+)'
        matches = re.finditer(section_pattern, text, re.MULTILINE)
        
        for match in matches:
            section_title = match.group(2).strip()
            if len(section_title) < 100:  # Likely a heading, not a sentence
                sections.append(section_title)
        
        return sections[:10]  # Limit to first 10 sections
    
    def _normalize_chapter_number(self, chapter_str: str) -> int:
        """Convert chapter number to integer"""
        # Handle roman numerals
        roman_map = {
            'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5,
            'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10
        }
        
        # Handle word numbers
        word_map = {
            'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
            'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10
        }
        
        chapter_str = chapter_str.strip().upper()
        
        if chapter_str in roman_map:
            return roman_map[chapter_str]
        elif chapter_str.lower() in word_map:
            return word_map[chapter_str.lower()]
        else:
            try:
                return int(chapter_str)
            except ValueError:
                return 1


class ChunkProcessor:
    """Splits chapters into manageable chunks for AI processing"""
    
    def __init__(self, max_chunk_size: int = 2000):
        self.max_chunk_size = max_chunk_size
    
    def chunk_chapter(self, chapter: Chapter) -> List[Dict[str, str]]:
        """
        Split chapter into chunks for processing
        
        Returns:
            List of chunks with metadata
        """
        chunks = []
        content = chapter.content
        
        # Split by paragraphs
        paragraphs = content.split('\n\n')
        
        current_chunk = ""
        chunk_num = 0
        
        for para in paragraphs:
            if len(current_chunk) + len(para) > self.max_chunk_size and current_chunk:
                # Save current chunk
                chunks.append({
                    'chapter_num': chapter.number,
                    'chapter_title': chapter.title,
                    'chunk_num': chunk_num,
                    'content': current_chunk.strip()
                })
                chunk_num += 1
                current_chunk = para
            else:
                current_chunk += "\n\n" + para
        
        # Add last chunk
        if current_chunk.strip():
            chunks.append({
                'chapter_num': chapter.number,
                'chapter_title': chapter.title,
                'chunk_num': chunk_num,
                'content': current_chunk.strip()
            })
        
        return chunks


# Test function
if __name__ == "__main__":
    if BOOKS_ENABLED:
        processor = DocumentProcessor()
        print("✅ Document processor initialized successfully")
        print("Supported formats: PDF, EPUB, DOCX")
    else:
        print("❌ Install required packages: pip install -r requirements-books.txt")

