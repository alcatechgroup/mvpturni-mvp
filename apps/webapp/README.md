# Turni — WebApp (`apps/webapp`)

WebApp do Turni (Flutter), usado por **Contratante** e **Profissional**. Entregue como **Flutter Web** no MVP, com o mesmo codebase preparado para virar apps nativos Android/iOS no futuro (ADR-001). Liga-se ao backend pelo contrato de API (`contracts/`) e aos design tokens (`packages/design-tokens`) — não compartilha código de runtime com o Backoffice.

## Rodar

O WebApp é servido como build estático pelo comando único do monorepo (raiz):

```bash
make setup   # builda o WebApp e serve em http://localhost:8003
```

Para desenvolvimento iterativo do Flutter, no host:

```bash
cd apps/webapp
flutter pub get
flutter run -d chrome      # hot reload no browser
flutter build web          # gera build/web (servido pelo container `webapp`)
flutter test               # testes de widget
```

## Notas

- STORY-006 entrega apenas um **placeholder mínimo** na rota raiz. O Design System (DDR-001) e o hello world de verdade entram na **STORY-008**.
- E2E em browser real (Playwright contra o build servido) entra com a STORY-008/009.
- Pré-requisito: Flutter SDK ≥ 3.41 no host.
