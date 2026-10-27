# Sabt CRM — мобильный клиент

Мобильный клиент CRM/ERP агентства **WeBrand**: задачи, проекты, клиенты,
контент (SMM), финансы, сотрудники, файлы, календарь, уведомления и
AI-ассистент. Тёмная «liquid glass» дизайн-система, фирменный фиолетовый
Sabt `#59479e`, русский интерфейс.

## Быстрый старт

```bash
flutter pub get
flutter run                     # устройство/эмулятор по умолчанию
flutter run -d chrome           # Web
flutter run -d windows          # Windows
```

API по умолчанию — production. Другой бэкенд:

```bash
flutter run --dart-define=API_BASE_URL=https://example.com/api
```

## Проверка перед коммитом

```bash
dart format <изменённые файлы>
flutter analyze   # strict-casts / strict-inference / strict-raw-types
flutter test
```

Анализатор настроен строго (`analysis_options.yaml`): дерево должно
проходить все включённые правила без исключений. Новое правило добавляется
только вместе с чистым деревом — вечно игнорируемый линт хуже его отсутствия.

## Архитектура

Feature-first, слои внутри каждой фичи:

```
lib/
  main.dart            точка входа: edge-to-edge, bootstrap, ProviderScope
  bootstrap.dart       сборка всех сервисов (Hive, API, Firebase, push…)
  app.dart             MaterialApp.router + фоновый слой + баннеры
  core/
    config/            окружение (AppEnv)
    design/            Motion, стекло (GlassSurface/Tokens), фон, бренд-знак
    theme/             AppColors (якорь — #59479e), типографика, тема M3
    network/           ApiClient (Dio), токены, иерархия ApiException
    router/            GoRouter: redirect по состоянию авторизации
    widgets/           AppButton, AppPage, карточки, чипы, скелетоны…
  features/<feature>/
    domain/            чистые модели и правила (без Flutter)
    data/              репозитории поверх ApiClient/кэша
    presentation/      страницы, провайдеры Riverpod, локальные виджеты
test/
  unit/                чистые правила и рендер страниц
  *_test.dart          виджет-тесты ключевых флоу (вход, движение)
```

Ключевые соглашения:

- **Темы** — две: тёмный «liquid graphite» и светлый «liquid porcelain».
  Цвета живут в `AppPalette` (ThemeExtension), виджеты читают только
  `context.palette` — статический `AppColors` остался константами тёмного
  пресета для мест без контекста. Якорь обеих тем — фирменный #59479e.
  Выбор (тёмная/светлая/системная) — `themeModeProvider`, сохраняется в
  Hive prefs, меняется в Настройки → Внешний вид; по умолчанию тёмная.
- **Состояние** — Riverpod. Роутер слушает `authControllerProvider` и сам
  решает redirect; страницы не навигируют после логина вручную.
- **Движение** — только через `core/design/motion.dart`: шкала длительностей
  (press 100 мс … entrance 950 мс), кривые `easeOut/drawer/spring`.
  Анимируются opacity и transform, layout не анимируется никогда.
  `prefers-reduced-motion` обнуляет все длительности в одном месте.
- **Стекло** — один `BackdropFilter` на Z-плоскость; стекло не вкладывается
  в стекло, чипы и контент внутри — сплошные поверхности.
- **Ошибки сети** — иерархия `ApiException` (`TwoFactorRequiredException`,
  `AccountBlockedException`, `SessionExpiredException`): UI ветвиться по
  типу, а не по строкам.
- **Кэш** — Hive (`ResponseCache` + `CachedJson`): офлайн-восстановление
  сессии и последних данных.

## Экран входа

Эталонный экран приложения (`features/auth`):

- одна `Motion.entrance`-шкала на 950 мс: аврора-фон, бренд-знак, вордмарк,
  карточка и подвал появляются каскадом от одного тикера (`StaggeredEntrance`);
- живой фон только здесь: шелл держит свой фон статичным, чтобы GPU не
  бодрствовал весь день;
- дышащий стеклянный знак с бликом-проблеском (`AnimatedBrandMark`);
- поля с фокус-подсветкой и разворачивающимися ошибками (`LoginField`),
  валидация — чистая и тестируемая (`domain/login_validation.dart`);
- отказ сервера — одна тряска карточки (`Shake`, затухающая синусоида)
  + haptic, а не красный баннер в лицо;
- 2FA — шесть ячеек с автопереходом, вставкой из буфера и автоподтверждением
  на шестой цифре (`OtpField`: один скрытый TextField, ячейки — проекция);
- кнопка морфится idle → «Входим…» → галочка, нарисованная штрихом
  (`LoginButton`); дальше пользователя уносит переход роутера;
- при открытой клавиатуре знак уменьшается, вордмарк растворяется.

## Сборка релиза

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release
```
