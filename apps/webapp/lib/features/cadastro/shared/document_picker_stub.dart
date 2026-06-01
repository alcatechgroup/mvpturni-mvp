import '../completar_cadastro_service.dart' show ArquivoUpload;

/// Stub para plataformas sem `dart:js_interop` (VM/teste). Em produção o WebApp roda a
/// implementação web; os testes injetam um picker fake, então isto nunca é chamado.
Future<List<ArquivoUpload>?> pickDocuments() async => null;
