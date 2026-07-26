import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;

  const PdfViewerScreen({
    Key? key,
    required this.title,
    required this.buildPdf,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await widget.buildPdf();
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading PDF: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_isLoading && _pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: "Print",
              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout: (format) async => _pdfBytes!,
                  name: '${widget.title}.pdf',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: "Share",
              onPressed: () async {
                await Printing.sharePdf(
                  bytes: _pdfBytes!,
                  filename: '${widget.title}.pdf',
                );
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfBytes == null
              ? const Center(child: Text("Could not generate PDF"))
              : InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: PdfPreview(
                    build: (format) => _pdfBytes!,
                    useActions: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                  ),
                ),
    );
  }
}
