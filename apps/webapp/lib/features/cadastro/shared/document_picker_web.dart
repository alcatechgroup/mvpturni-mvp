import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../completar_cadastro_service.dart' show ArquivoUpload;

/// Abre o seletor de arquivos nativo do browser (JPG/PNG/PDF, múltiplos) e devolve os
/// bytes lidos. Sem plugin/method channel — usa o `<input type="file">` do DOM.
Future<List<ArquivoUpload>?> pickDocuments() async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = '.jpg,.jpeg,.png,.pdf,image/jpeg,image/png,application/pdf'
    ..multiple = true
    ..style.display = 'none';

  web.document.body?.appendChild(input);
  final completer = Completer<List<ArquivoUpload>?>();

  void finalizar(List<ArquivoUpload>? r) {
    if (!completer.isCompleted) completer.complete(r);
    input.remove();
  }

  // O handler precisa ser sync (toJS não converte função async); a leitura dos bytes
  // (assíncrona) roda em um closure disparado sem await.
  Future<void> lerArquivos() async {
    try {
      final files = input.files;
      if (files == null || files.length == 0) {
        finalizar(null);
        return;
      }
      final out = <ArquivoUpload>[];
      for (var i = 0; i < files.length; i++) {
        final file = files.item(i)!;
        final buffer = await file.arrayBuffer().toDart;
        out.add(
          ArquivoUpload(
            bytes: buffer.toDart.asUint8List(),
            filename: file.name,
          ),
        );
      }
      finalizar(out);
    } catch (_) {
      finalizar(null);
    }
  }

  input.onchange = ((web.Event _) {
    unawaited(lerArquivos());
  }).toJS;

  // Cancelar o diálogo dispara 'cancel' em browsers modernos — resolve sem arquivos.
  input.oncancel = ((web.Event _) => finalizar(null)).toJS;

  input.click();
  return completer.future;
}
