import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:ma_1/models/manual_entry.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/rag_api_service.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/widgets/pulse_logo.dart';

class ManualsLibraryScreen extends StatefulWidget {
  const ManualsLibraryScreen({super.key});

  @override
  State<ManualsLibraryScreen> createState() => _ManualsLibraryScreenState();
}

class _ManualsLibraryScreenState extends State<ManualsLibraryScreen> {
  final _titleCtrl = TextEditingController();
  String _selectedModel = 'Aeonmed VG70';
  String _selectedCategory = 'Service Manual';
  String? _fileName;
  String? _fileType;
  int? _fileSize;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  double _progress = 0;
  String _indexingStage = 'Ready';
  String? _lastIndexingError;
  String? _storageCheckMessage;
  bool _isCheckingStorage = false;
  bool _savedLocalCopy = false;
  late Future<List<ManualEntry>> _manualsFuture;

  static const _models = [
    'Aeonmed VG70',
    'Drager Evita V500',
    'Mindray A5',
    'WATO EX-35',
  ];

  static const _categories = [
    'Operation Manual',
    'Service Manual',
    'Calibration Guide',
    'Schematic / Drawing',
  ];

  @override
  void initState() {
    super.initState();
    _manualsFuture = _loadManuals();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<List<ManualEntry>> _loadManuals() async {
    final rows = await DatabaseHelper.instance.getManualEntries();
    return rows.map((row) => ManualEntry.fromMap(row)).toList();
  }

  Future<void> _refreshManuals() async {
    final future = _loadManuals();
    setState(() {
      _manualsFuture = future;
    });
    await future;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _manualContentSummary(
      Uint8List bytes, String? extension, String fileName) {
    final normalized = (extension ?? '').toLowerCase();
    if (normalized == 'txt' || normalized == 'csv') {
      try {
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        if (text.isNotEmpty) {
          return text.length > 40000 ? text.substring(0, 40000) : text;
        }
      } catch (_) {}
    }
    return 'Uploaded manual file: $fileName (${_formatFileSize(bytes.length)}). Stored locally for technician reference and Pulse AI RAG context.';
  }

  IconData _manualIcon(String? extension) {
    return switch ((extension ?? '').toLowerCase()) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'png' || 'jpg' || 'jpeg' => Icons.image_outlined,
      'txt' || 'csv' => Icons.description_outlined,
      _ => Icons.article_outlined,
    };
  }

  Future<void> _pickManual() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    if (bytes.length > 50 * 1024 * 1024) {
      _showSnack('Use a PDF under 50 MB for reliable indexing.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _fileType = file.extension ?? 'pdf';
      _fileSize = file.size;
      _fileBytes = bytes;
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text =
            file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      }
    });
  }

  Future<void> _uploadManual() async {
    final title = _titleCtrl.text.trim();
    final fileName = _fileName;
    final bytes = _fileBytes;
    if (title.isEmpty || fileName == null || bytes == null || _isUploading) {
      return;
    }
    final retryingCloudIndex = _savedLocalCopy && _lastIndexingError != null;

    setState(() {
      _isUploading = true;
      _progress = retryingCloudIndex ? 0.36 : 0;
      _indexingStage = retryingCloudIndex
          ? 'Retrying cloud indexing'
          : 'Saving secure local copy';
      _lastIndexingError = null;
      _savedLocalCopy = retryingCloudIndex;
    });

    final progressTimer =
        Timer.periodic(const Duration(milliseconds: 260), (_) {
      if (!mounted) return;
      setState(() => _progress = (_progress + 0.07).clamp(0, 0.92));
    });

    try {
      if (!retryingCloudIndex) {
        await DatabaseHelper.instance.addManualEntry({
          'machine_model': _selectedModel,
          'category': _selectedCategory,
          'title': title,
          'content': _manualContentSummary(bytes, _fileType, fileName),
          'file_name': fileName,
          'file_type': _fileType,
          'file_size': bytes.length,
          'file_bytes': bytes,
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (!mounted) return;
        setState(() {
          _savedLocalCopy = true;
          _indexingStage = 'Uploading PDF to manuals bucket';
          _progress = _progress < 0.36 ? 0.36 : _progress;
        });
      }

      if (!mounted) return;
      setState(() {
        _indexingStage = 'Extracting pages and embedding manual chunks';
        _progress = _progress < 0.58 ? 0.58 : _progress;
      });

      final result = await RagApiService.instance
          .uploadAndIndexManual(
            title: title,
            machineModel: _selectedModel,
            category: _selectedCategory,
            fileName: fileName,
            fileType: _fileType,
            bytes: bytes,
          )
          .timeout(
            const Duration(minutes: 12),
            onTimeout: () => throw TimeoutException(
              'The RAG backend is still processing this manual after 12 minutes. Large PDFs can take a long time while Pulse extracts pages, creates embeddings, and stores chunks.',
            ),
          );

      progressTimer.cancel();
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _progress = 1;
        _indexingStage = 'Indexed and ready for Pulse AI';
        _lastIndexingError = null;
        _fileName = null;
        _fileType = null;
        _fileSize = null;
        _fileBytes = null;
      });
      _titleCtrl.clear();
      _showSnack(
        'Indexed $title with ${result.chunks} searchable chunks.',
        isSuccess: true,
      );
      await _refreshManuals();
    } catch (e) {
      progressTimer.cancel();
      if (!mounted) return;
      final message = _friendlyIndexingError(e);
      setState(() {
        _isUploading = false;
        _progress = 0;
        _indexingStage = _savedLocalCopy
            ? 'Local copy saved, cloud index failed'
            : 'Upload failed';
        _lastIndexingError = message;
      });
      _showSnack(
        _savedLocalCopy
            ? 'Saved locally, but cloud RAG indexing failed.'
            : 'Manual upload failed.',
      );
      await _refreshManuals();
    }
  }

  String _friendlyIndexingError(Object error) {
    final raw = error.toString();
    if (raw.contains('XMLHttpRequest') ||
        raw.contains('ClientException') ||
        raw.contains('Failed to fetch') ||
        raw.contains('Connection refused')) {
      return 'The manual was saved locally, but Pulse could not reach the RAG backend at http://localhost:5000/api/rag/ingest. Start the backend service, then index again.';
    }
    if (raw.contains('Unauthorized') || raw.contains('401')) {
      return 'The manual was saved locally, but the RAG backend rejected the request as unauthorized. Sign in again so Supabase can provide a fresh access token, then retry indexing.';
    }
    if (raw.contains('Sign in again')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.contains('row-level security') || raw.contains('42501')) {
      return 'The manual was saved locally, but Supabase blocked cloud indexing with RLS. Run backend/rag_rls_fix.sql in the Supabase SQL Editor, restart the backend, then retry indexing.';
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      return 'The manual was saved locally, but the backend is taking too long to extract pages, create Gemini embeddings, and store vector chunks. Try a smaller manual, wait for the current backend job to finish, or split the PDF into sections before retrying.';
    }
    if (raw.contains('Bucket not found') || raw.contains('manuals')) {
      return 'Supabase Storage upload failed. Run backend/rag_storage_fix.sql in the Supabase SQL Editor, make sure it is a normal private Storage bucket named "manuals" rather than a vector bucket, then retry. Details: $raw';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.warning,
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
      ),
    );
  }

  Future<void> _checkStorage() async {
    if (_isCheckingStorage) return;
    setState(() {
      _isCheckingStorage = true;
      _storageCheckMessage = null;
    });
    final result = await RagApiService.instance.checkManualStorage();
    if (!mounted) return;
    setState(() {
      _isCheckingStorage = false;
      _storageCheckMessage = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        titleSpacing: 0,
        title: const Row(
          children: [
            PulseLogo(size: 30, borderRadius: 8),
            SizedBox(width: 10),
            Text('Manuals Library'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshManuals,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildRagStatusCard(),
            const SizedBox(height: 14),
            _buildUploadPanel(),
            const SizedBox(height: 18),
            _buildLibraryPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPanel() {
    final canUpload = !_isUploading &&
        _fileBytes != null &&
        _titleCtrl.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(Icons.cloud_upload_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload manuals for Pulse AI',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Add PDF service manuals, calibration guides, and schematics for grounded RAG answers.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPipelineStatus(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              if (compact) {
                return Column(
                  children: [
                    _titleField(),
                    const SizedBox(height: 12),
                    _modelField(),
                    const SizedBox(height: 12),
                    _categoryField(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _titleField()),
                  const SizedBox(width: 12),
                  Expanded(child: _modelField()),
                  const SizedBox(width: 12),
                  Expanded(child: _categoryField()),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _isUploading ? null : _pickManual,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: _fileName == null
                    ? AppTheme.muted.withValues(alpha: 0.58)
                    : AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _fileName == null
                      ? AppTheme.divider
                      : AppTheme.success.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  _iconTile(
                    _fileName == null
                        ? Icons.picture_as_pdf_outlined
                        : _manualIcon(_fileType),
                    color: _fileName == null
                        ? AppTheme.secondary
                        : AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'Select PDF manual',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _fileName == null
                                ? AppTheme.textPrimary
                                : AppTheme.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _fileName == null
                              ? 'PDF only. The file is stored locally and sent to the RAG indexer.'
                              : _formatFileSize(_fileSize),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Uploading and indexing for manual-aware answers',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              color: AppTheme.secondary,
              backgroundColor: AppTheme.divider,
            ),
          ],
          if (_lastIndexingError != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastIndexingError!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: canUpload ? _uploadManual : null,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_lastIndexingError == null
                  ? 'Index manual'
                  : 'Retry cloud indexing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRagStatusCard() {
    final statusColor = _lastIndexingError != null
        ? AppTheme.warning
        : _isUploading
            ? AppTheme.secondary
            : AppTheme.success;
    final title = _lastIndexingError != null
        ? 'Manual saved, indexing needs attention'
        : _isUploading
            ? 'Indexing manual context'
            : 'RAG manual workspace';
    final subtitle = _lastIndexingError != null
        ? 'Pulse can keep the local copy now. Cloud answers need the RAG backend and Supabase bucket to complete indexing.'
        : 'Upload service PDFs here so Pulse AI can cite manual context during fault triage and calibration support.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.deepBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_stories_outlined,
                color: Colors.white.withValues(alpha: 0.94), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _statusPill(_isUploading ? '${(_progress * 100).round()}%' : 'Ready',
              statusColor),
        ],
      ),
    );
  }

  Widget _buildPipelineStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statusPill(_savedLocalCopy ? 'Local copy saved' : 'Local save',
              _savedLocalCopy ? AppTheme.success : AppTheme.textSecondary),
          _statusPill(
              _indexingStage,
              _lastIndexingError == null
                  ? AppTheme.secondary
                  : AppTheme.warning),
          _statusPill('Backend: localhost:5000', AppTheme.deepBlue),
          ActionChip(
            avatar: _isCheckingStorage
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined, size: 16),
            label: Text(_isCheckingStorage ? 'Checking...' : 'Check storage'),
            onPressed: _isCheckingStorage ? null : _checkStorage,
            labelStyle: const TextStyle(
              color: AppTheme.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
            ),
          ),
          if (_storageCheckMessage != null)
            SizedBox(
              width: double.infinity,
              child: Text(
                _storageCheckMessage!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleCtrl,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Manual title',
        hintText: 'VG70 service manual',
      ),
    );
  }

  Widget _modelField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedModel,
      decoration: const InputDecoration(labelText: 'Machine model'),
      items: _models
          .map((model) => DropdownMenuItem(value: model, child: Text(model)))
          .toList(),
      onChanged: _isUploading
          ? null
          : (value) => setState(() => _selectedModel = value ?? _selectedModel),
    );
  }

  Widget _categoryField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: const InputDecoration(labelText: 'Manual category'),
      items: _categories
          .map((category) =>
              DropdownMenuItem(value: category, child: Text(category)))
          .toList(),
      onChanged: _isUploading
          ? null
          : (value) =>
              setState(() => _selectedCategory = value ?? _selectedCategory),
    );
  }

  Widget _buildLibraryPanel() {
    return FutureBuilder<List<ManualEntry>>(
      future: _manualsFuture,
      builder: (context, snapshot) {
        final manuals = snapshot.data ?? const <ManualEntry>[];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Indexed manual library',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  Text(
                    '${manuals.length} docs',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(minHeight: 2)
              else if (manuals.isEmpty)
                _emptyLibrary()
              else
                ...manuals.map(_manualTile),
            ],
          ),
        );
      },
    );
  }

  Widget _manualTile(ManualEntry manual) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          _iconTile(_manualIcon(manual.fileType)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manual.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${manual.machineModel} | ${manual.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatFileSize(manual.fileSize),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLibrary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(
        color: AppTheme.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, color: AppTheme.secondary, size: 34),
          SizedBox(height: 10),
          Text(
            'No manuals uploaded yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Upload your PDF manuals here so Pulse AI can answer from them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconTile(IconData icon, {Color color = AppTheme.secondary}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 21),
    );
  }
}
