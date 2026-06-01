// Seletor de documentos do completar cadastro (STORY-023 CA-5).
//
// Em vez do `file_picker` (que no Flutter Web lança MissingPluginException — o canal
// nativo não é registrado), usamos o <input type="file"> nativo do browser via
// `package:web` (já dependência), sem plugin/method channel. Import condicional: o stub
// (VM/teste) nunca é exercitado em produção; o WebApp roda sempre a implementação web.
export 'document_picker_stub.dart'
    if (dart.library.js_interop) 'document_picker_web.dart';
