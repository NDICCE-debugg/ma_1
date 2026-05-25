// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _pkceVerifierKey = 'supabase.auth.token-code-verifier';
const _flutterPkceVerifierKey = 'flutter.$_pkceVerifierKey';
const _supabaseCallbackParams = {
  'code',
  'state',
  'error',
  'error_code',
  'error_description',
};

void cleanStaleSupabaseCallbackUrl() {
  if (!hasSupabaseAuthCallback()) return;

  final hasCode = Uri.base.queryParameters.containsKey('code');
  if (hasCode && hasSupabasePkceVerifier()) return;

  clearSupabaseCallbackUrl();
}

bool hasSupabaseAuthCallback() {
  final params = Uri.base.queryParameters;
  return _supabaseCallbackParams.any(params.containsKey) ||
      _fragmentParameters().keys.any(_supabaseCallbackParams.contains);
}

bool hasSupabasePkceVerifier() =>
    html.window.localStorage[_pkceVerifierKey] != null ||
    html.window.localStorage[_flutterPkceVerifierKey] != null;

void clearSupabaseCallbackUrl() {
  final uri = Uri.base;
  final cleanParams = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => _supabaseCallbackParams.contains(key));
  final cleanUri = uri.replace(
    queryParameters: cleanParams.isEmpty ? null : cleanParams,
    fragment: '',
  );

  html.window.history.replaceState(
    null,
    html.document.title,
    cleanUri.toString(),
  );
}

Map<String, String> _fragmentParameters() {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return const {};
  try {
    return Uri.splitQueryString(
      fragment.startsWith('?') ? fragment.substring(1) : fragment,
    );
  } catch (_) {
    return const {};
  }
}
