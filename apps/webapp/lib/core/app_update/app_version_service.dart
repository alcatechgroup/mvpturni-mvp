import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_version.dart';

/// Lê a versão rodando (`currentVersion`) e busca a versão publicada no servidor
/// (`/version.json`) — STORY-037 CA-1.
///
/// Mesma origem, path relativo. O GET vai com `Cache-Control: no-cache` no header
/// **e** `?t=<epochMs>` como cache-buster defensivo (IDR-017): alguns proxies/CDNs
/// colapsam GETs idênticos mesmo com `no-cache`. Timeout de 5 s.
///
/// `fetchServerVersion` **propaga** falhas (rede, status != 200, JSON inválido,
/// timeout); quem chama (`AppUpdateController`) decide ignorá-las silenciosamente
/// para manter o fluxo não-bloqueante.
class AppVersionService {
  AppVersionService({http.Client? client, this.timeout = _defaultTimeout})
    : _client = client ?? http.Client();

  static const _defaultTimeout = Duration(seconds: 5);

  final http.Client _client;
  final Duration timeout;

  /// Versão que está rodando agora no dispositivo.
  AppVersion get currentVersion => AppVersion.current();

  /// Busca `{"version":"..."}` em `/version.json`. Lança em qualquer falha.
  Future<AppVersion> fetchServerVersion() async {
    final uri = Uri.parse('/version.json').replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );

    final response = await _client
        .get(uri, headers: const {'Cache-Control': 'no-cache'})
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'version.json respondeu ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['version'] is! String) {
      throw const FormatException('version.json sem campo "version" string');
    }

    return AppVersion(decoded['version'] as String);
  }
}
