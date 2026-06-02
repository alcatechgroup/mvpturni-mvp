import 'install_controller.dart';

/// Instância única da ação "Instalar app" do WebApp (STORY-042 / IDR-020).
///
/// Iniciada no `main()` (`installController.start()`) ao lado de `appUpdate.start()`
/// e consumida pelo `InstallActionSlot` nos pontos de plugagem (login, cadastros,
/// app shell). Singleton coerente com `appUpdate` e `AuthService`.
final InstallController installController = InstallController();
