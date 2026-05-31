/// Versão do app como value object (STORY-037 / IDR-017).
///
/// Envolve a string da tag (`vX.Y.Z-rc.N`) ou o sentinela `dev` (build local sem
/// `--dart-define=APP_VERSION`). Igualdade é por valor — duas `AppVersion` com a
/// mesma string são iguais.
class AppVersion {
  const AppVersion(this.value);

  /// Versão que está rodando agora no dispositivo. Injetada em build pelo
  /// pipeline via `--dart-define=APP_VERSION` (IDR-002); `dev` em build local.
  factory AppVersion.current() => const AppVersion(
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
  );

  /// A tag bruta (`vX.Y.Z-rc.N` ou `dev`).
  final String value;

  /// `true` quando não há tag de release injetada (`dev` ou vazio). Nesse caso a
  /// auto-atualização fica desabilitada (IDR-017 §dev desabilita).
  bool get isDev => value.isEmpty || value == 'dev';

  /// `true` se a outra versão é diferente desta (por valor).
  bool isDifferentFrom(AppVersion other) => value != other.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppVersion && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
