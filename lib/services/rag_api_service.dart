import 'dart:convert';
import 'dart:typed_data';

import 'package:ma_1/services/api_client.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RagSource {
  final String title;
  final String fileName;
  final int? pageNumber;
  final String? sectionTitle;
  final double? similarity;

  const RagSource({
    required this.title,
    required this.fileName,
    this.pageNumber,
    this.sectionTitle,
    this.similarity,
  });

  factory RagSource.fromJson(Map<String, dynamic> json) {
    return RagSource(
      title: json['title']?.toString() ?? 'Manual',
      fileName: json['file_name']?.toString() ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt(),
      sectionTitle: json['section_title']?.toString(),
      similarity: (json['similarity'] as num?)?.toDouble(),
    );
  }
}

class RagQueryResult {
  final String answer;
  final List<RagSource> sources;
  final int contextCount;

  const RagQueryResult({
    required this.answer,
    required this.sources,
    required this.contextCount,
  });

  bool get hasManualContext => sources.isNotEmpty && contextCount > 0;

  factory RagQueryResult.fromJson(Map<String, dynamic> json) {
    final sources = (json['sources'] as List? ?? const [])
        .whereType<Map>()
        .map((source) => RagSource.fromJson(Map<String, dynamic>.from(source)))
        .toList();
    return RagQueryResult(
      answer: json['answer']?.toString() ?? '',
      sources: sources,
      contextCount: (json['context_count'] as num?)?.toInt() ?? sources.length,
    );
  }
}

class RagIngestResult {
  final String manualId;
  final String status;
  final int pages;
  final int chunks;

  const RagIngestResult({
    required this.manualId,
    required this.status,
    required this.pages,
    required this.chunks,
  });

  factory RagIngestResult.fromJson(Map<String, dynamic> json) {
    return RagIngestResult(
      manualId: json['manual_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      chunks: (json['chunks'] as num?)?.toInt() ?? 0,
    );
  }
}

class RagApiService {
  static final RagApiService instance = RagApiService._init();
  RagApiService._init();

  static const String manualBucket = 'manuals';

  Future<RagIngestResult> uploadAndIndexManual({
    required String title,
    required String machineModel,
    required String category,
    required String fileName,
    required String? fileType,
    required Uint8List bytes,
  }) async {
    final hasValidSession = await AuthService.instance.checkSession();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception(
        'Sign in again before indexing manuals. Supabase Storage requires an authenticated user folder.',
      );
    }
    if (!hasValidSession) {
      throw Exception(
        'Your Pulse session expired. Please sign in again before indexing manuals.',
      );
    }
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(fileName)}';
    final contentType = _contentTypeFor(fileName, fileType);

    try {
      await Supabase.instance.client.storage.from(manualBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
              cacheControl: '3600',
            ),
          );
    } on StorageException catch (e) {
      throw Exception(
        'Supabase Storage upload failed: ${e.statusCode ?? 'unknown'} '
        '${e.error ?? ''} ${e.message}',
      );
    }

    final response = await ApiClient.instance.post('/rag/ingest', {
      'title': title,
      'machine_model': machineModel,
      'category': category,
      'file_name': fileName,
      'file_type': fileType ?? 'pdf',
      'file_size': bytes.length,
      'storage_path': storagePath,
    });
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Manual indexing failed');
    }
    return RagIngestResult.fromJson(body);
  }

  Future<String> checkManualStorage() async {
    final hasValidSession = await AuthService.instance.checkSession();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return 'Not signed in. Supabase Storage requires an authenticated user.';
    }
    if (!hasValidSession) {
      return 'Your Pulse session expired. Sign in again so Supabase can provide a fresh storage token.';
    }

    try {
      await Supabase.instance.client.storage.from(manualBucket).list(
            path: userId,
            searchOptions: const SearchOptions(limit: 1),
          );
      return 'Storage bucket is reachable for this user.';
    } on StorageException catch (e) {
      return 'Storage check failed: ${e.statusCode ?? 'unknown'} '
          '${e.error ?? ''} ${e.message}';
    } catch (e) {
      return 'Storage check failed: $e';
    }
  }

  Future<RagQueryResult> queryManuals({
    required String query,
    String? machineModel,
  }) async {
    final response = await ApiClient.instance.post('/rag/query', {
      'query': query,
      if (machineModel != null && machineModel.trim().isNotEmpty)
        'machine_model': machineModel.trim(),
    });
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Manual RAG query failed');
    }
    return RagQueryResult.fromJson(body);
  }

  String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  String _contentTypeFor(String fileName, String? fileType) {
    final ext = (fileType ?? fileName.split('.').last).toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }
}
