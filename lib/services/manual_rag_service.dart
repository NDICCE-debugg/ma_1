import 'dart:typed_data';

import 'package:ma_1/models/manual_entry.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/gemini_service.dart';

class ManualRagContext {
  final String promptBlock;
  final List<GeminiAttachment> attachments;
  final List<String> sourceTitles;

  const ManualRagContext({
    required this.promptBlock,
    required this.attachments,
    required this.sourceTitles,
  });

  bool get hasContext => sourceTitles.isNotEmpty;
}

class ManualRagService {
  static final ManualRagService instance = ManualRagService._init();
  ManualRagService._init();

  static const int _maxSnippets = 5;
  static const int _maxPdfAttachments = 2;
  static const int _maxInlinePdfBytes = 8 * 1024 * 1024;

  Future<ManualRagContext> buildContext(String query) async {
    final rows = await DatabaseHelper.instance.getManualEntries();
    final manuals = rows.map((row) => ManualEntry.fromMap(row)).toList();
    if (manuals.isEmpty) {
      return const ManualRagContext(
        promptBlock: '',
        attachments: [],
        sourceTitles: [],
      );
    }

    final ranked = manuals
        .map((manual) => _RankedManual(manual, _scoreManual(manual, query)))
        .where((ranked) => ranked.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final selected = ranked.isEmpty
        ? manuals.take(3).map((manual) => _RankedManual(manual, 1)).toList()
        : ranked.take(6).toList();

    final snippets = <String>[];
    final sourceTitles = <String>[];
    final attachments = <GeminiAttachment>[];

    for (final ranked in selected) {
      final manual = ranked.manual;
      final sourceLabel = _sourceLabel(manual);
      if (!sourceTitles.contains(sourceLabel)) sourceTitles.add(sourceLabel);

      final chunks = _chunksFor(manual)
          .map((chunk) => _RankedChunk(chunk, _scoreText(chunk, query)))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      for (final chunk in chunks.take(2)) {
        if (snippets.length >= _maxSnippets) break;
        snippets.add('SOURCE: $sourceLabel\n${chunk.text}');
      }

      if (attachments.length < _maxPdfAttachments &&
          _isPdf(manual) &&
          manual.fileBytes != null &&
          manual.fileBytes!.isNotEmpty &&
          manual.fileBytes!.length <= _maxInlinePdfBytes) {
        attachments.add(
          GeminiAttachment(
            name: manual.fileName ?? '${manual.title}.pdf',
            mimeType: 'application/pdf',
            bytes: Uint8List.fromList(manual.fileBytes!),
          ),
        );
      }
    }

    if (snippets.isEmpty && attachments.isEmpty) {
      return const ManualRagContext(
        promptBlock: '',
        attachments: [],
        sourceTitles: [],
      );
    }

    final prompt = '''
MANUAL RAG CONTEXT
Use the following uploaded service manual context before answering. If a relevant PDF is attached, inspect it directly as the primary source. Cite source titles in your answer under "Manual sources used". If the manuals do not contain enough information, say what is missing and give safe next checks rather than inventing specifications.

${snippets.join('\n\n---\n\n')}
''';

    return ManualRagContext(
      promptBlock: prompt,
      attachments: attachments,
      sourceTitles: sourceTitles,
    );
  }

  String _sourceLabel(ManualEntry manual) {
    final fileName = manual.fileName;
    final suffix = fileName == null || fileName.trim().isEmpty
        ? manual.category
        : fileName;
    return '${manual.title} | ${manual.machineModel} | $suffix';
  }

  List<String> _chunksFor(ManualEntry manual) {
    final text = manual.content.trim();
    final header =
        'Manual: ${manual.title}\nMachine model: ${manual.machineModel}\nCategory: ${manual.category}\nFile: ${manual.fileName ?? 'N/A'}\n';
    if (text.length <= 1200) return ['$header\n$text'];

    final chunks = <String>[];
    for (var start = 0; start < text.length; start += 900) {
      final end = (start + 1200) > text.length ? text.length : start + 1200;
      chunks.add('$header\n${text.substring(start, end)}');
      if (chunks.length >= 8) break;
    }
    return chunks;
  }

  int _scoreManual(ManualEntry manual, String query) {
    final text = [
      manual.machineModel,
      manual.category,
      manual.title,
      manual.content,
      manual.fileName ?? '',
    ].join(' ');
    return _scoreText(text, query);
  }

  int _scoreText(String text, String query) {
    final haystack = _tokens(text);
    final needles = _tokens(query);
    if (needles.isEmpty) return 0;

    var score = 0;
    for (final token in needles) {
      if (haystack.contains(token)) score += token.length > 4 ? 3 : 1;
    }
    return score;
  }

  Set<String> _tokens(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toSet();
  }

  bool _isPdf(ManualEntry manual) {
    final type = (manual.fileType ?? '').toLowerCase();
    final name = (manual.fileName ?? '').toLowerCase();
    return type == 'pdf' || name.endsWith('.pdf');
  }
}

class _RankedManual {
  final ManualEntry manual;
  final int score;

  const _RankedManual(this.manual, this.score);
}

class _RankedChunk {
  final String text;
  final int score;

  const _RankedChunk(this.text, this.score);
}
