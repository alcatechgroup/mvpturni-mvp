import 'app_update_controller.dart';

/// Instância única da auto-atualização do WebApp (STORY-037).
///
/// Iniciada no `main()` e escutada pelo `UpdateBannerHost` no `MaterialApp.builder`.
/// O sucesso de login chama `appUpdate.onLoginSuccess()` (trigger iii — CA-2).
/// Em `dev` a checagem fica inerte (IDR-017), então é seguro referenciá-la em qualquer
/// ambiente. Singleton coerente com `AuthService` (também singleton no app).
final AppUpdateController appUpdate = AppUpdateController();
