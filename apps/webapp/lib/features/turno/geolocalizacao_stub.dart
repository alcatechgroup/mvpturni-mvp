import 'geolocalizacao.dart';

/// Stub para plataformas sem `dart:js_interop` (a VM dos testes unitários). Sem navegador, não há
/// Geolocation API — resolve como indisponível, coerente com PDR-008 (alerta-e-registra).
Future<PosicaoGeo> capturarPosicao() async =>
    const PosicaoGeo(razao: 'indisponivel');
