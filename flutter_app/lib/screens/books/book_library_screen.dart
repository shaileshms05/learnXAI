import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/book_service.dart';
import 'book_chat_screen.dart';
import 'teaching_screen.dart';

class BookLibraryScreen extends StatefulWidget {
  const BookLibraryScreen({super.key});

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  final BookService _bookService = BookService();
  final TextEditingController _pathController = TextEditingController();
  bool _isUploading = false;
  String? _uploadedBookId;
  String? _errorMessage;

  // For demo purposes, using a hardcoded path
  // In production, use file_picker package
  final String _demoBookPath = '/Users/shailesh/gdg-hackathon/ai-backend/books/Cloud-Computing.pdf';

  Future<void> _uploadBook() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final bookPath = _pathController.text.trim().isEmpty ? _demoBookPath : _pathController.text.trim();
      
      if (bookPath.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a book path or use the demo path';
          _isUploading = false;
        });
        return;
      }

      final fileType = bookPath.split('.').last.toLowerCase();
      
      if (!['pdf', 'epub', 'docx'].contains(fileType)) {
        setState(() {
          _errorMessage = 'Unsupported file type. Please use PDF, EPUB, or DOCX';
          _isUploading = false;
        });
        return;
      }

      print('📤 Uploading book: $bookPath (type: $fileType)');

      // Use a default user ID if not authenticated, or get from auth provider if available
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? 'anonymous_user';

      final metadata = await _bookService.uploadBook(
        filePath: bookPath,
        fileType: fileType,
        userId: userId,
      );

      if (metadata != null) {
        setState(() {
          _uploadedBookId = metadata.bookId;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Book uploaded: ${metadata.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to upload book. Please check the file path and try again.';
          _isUploading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to upload book'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Upload error: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upload_file, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Upload a Book',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pathController,
                      decoration: InputDecoration(
                        labelText: 'Book Path (PDF/EPUB/DOCX)',
                        hintText: _demoBookPath,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.folder),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading 
                            ? null 
                            : () {
                                print('🔘 Upload button clicked');
                                _uploadBook();
                              },
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload Book'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Uploaded Book Section
            if (_uploadedBookId != null) ...[
              const Text(
                'Recently Uploaded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.menu_book),
                      ),
                      title: const Text('Cloud Computing'),
                      subtitle: Text('Book ID: $_uploadedBookId'),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TeachingScreen(
                                      bookId: _uploadedBookId!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school, size: 20),
                              label: const Text('Learn'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookChatScreen(
                                      bookId: _uploadedBookId!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat, size: 20),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How it Works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Upload your book (PDF, EPUB, or DOCX)\n'
                      '2. AI extracts concepts automatically\n'
                      '3. Learn chapter by chapter with adaptive teaching\n'
                      '4. Chat with your book using AI\n'
                      '5. Track your mastery progress',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }
}

