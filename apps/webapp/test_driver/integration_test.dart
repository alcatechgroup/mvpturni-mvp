// Driver do integration_test para execução no Web (STORY-038 / IDR-010).
//
// `flutter drive` no alvo `web-server` precisa de um driver que apenas delega para
// `integrationDriver()`. Os cenários de fato vivem em `apps/webapp/integration_test/`.
// Em Android/iOS este driver não é necessário (`flutter test integration_test -d <device>`
// roda direto), mas no Web o canal de comunicação browser↔runner exige o drive.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
