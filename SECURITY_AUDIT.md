# Аудит информационной безопасности проекта Sabt CRM (Flutter)

**Дата проведения:** 26.10.2026  
**Объект аудита:** Мобильный и Web-клиент `sabt_crm` (Flutter / Dart 3)  
**Методология:** Статический анализ исходного кода (SAST), анализ архитектуры и платформенных конфигураций по стандарту **OWASP MASVS v2.0** (Mobile Application Security Verification Standard) и **OWASP Mobile Top 10**.  
**Статус кода:** Изменения в исходный код проекта не вносились (режим Read-Only).

---

## 1. Резюме аудита (Executive Summary)

Я провела полный аудит кодовой базы (`lib/`, `android/`, `ios/`, `web/`, `tool/`, конфигурационных файлов сборки). В целом архитектура проекта выстроена аккуратно:

### Сильные стороны текущей реализации
* **Single-Flight Refresh токенов:** В [`ApiClient`](lib/core/network/api_client.dart) реализован механизм защиты от гонки запросов при обновлении `accessToken` (`_refreshSingleFlight`), а публичные эндпоинты (`/auth/login`, `/auth/refresh` и др.) изолированы от отправки заголовка `Authorization`.
* **Использование системного хранилища ключей:** В [`TokenStore`](lib/core/network/token_store.dart) настроено использование `FlutterSecureStorage` с `KeychainAccessibility.first_unlock` для iOS.
* **Отключение телеметрии в Debug-режиме:** В [`FirebaseBootstrap`](lib/core/firebase/firebase_bootstrap.dart) сбор данных `Crashlytics` и `Analytics` корректно отключается в `kDebugMode`.
* **Нормализация ошибок API:** [`ApiClient._mapError`](lib/core/network/api_client.dart) скрывает сырые ответы сервера при статусах `>= 500`, не раскрывая внутренние стектрейсы бэкенда пользователю.

### Сводная таблица выявленных уязвимостей и рисков

| ID | Уровень риска | Категория OWASP MASVS | Описание проблемы | Статус |
|:---|:---:|:---|:---|:---:|
| **SEC-01** | 🔴 **HIGH** | `MASVS-STORAGE-1` | Хранение офлайн-кэша CRM в незашифрованном виде (Hive) и тихий фолбэк JWT-токенов в открытый бокс при сбое Keystore | Требует исправления |
| **SEC-02** | 🔴 **HIGH** | `MASVS-AUTH-2` | Отсутствие централизованных RBAC-проверок в `GoRouter` и на страницах финансов, доступов и журнала безопасности | Требует исправления |
| **SEC-03** | 🔴 **HIGH** | `MASVS-AUTH-1` | Бессрочное офлайн-восстановление сессии из незащищённого снимка `sabt.userSnapshot` и нюансы расчёта прав в `effectivePermissions` | Требует исправления |
| **SEC-04** | 🟠 **MEDIUM** | `MASVS-RESILIENCE-3` | Подпись релизной Android-сборки debug-ключом, отсутствие R8/ProGuard минификации и обфускации Dart | Требует исправления |
| **SEC-05** | 🟠 **MEDIUM** | `MASVS-STORAGE-2` | Незаблокированный автобэкап Android (`allowBackup`), позволяющий извлечь локальные базы Hive | Требует исправления |
| **SEC-06** | 🟠 **MEDIUM** | `MASVS-NETWORK-1` | Рассинхронизация токена в `RealtimeService` (Socket.IO) после refresh и отсутствие принудительной проверки `HTTPS/WSS` в релизе | Требует исправления |
| **SEC-07** | 🟠 **MEDIUM** | `MASVS-PLATFORM-2` | Открытие внешних ссылок (`launchUrl`) без валидации URI-схемы и мёртвый код в маршрутизации `NavigationService` | Требует исправления |
| **SEC-08** | 🟠 **MEDIUM** | `MASVS-CODE-4` | Загрузка файлов целиком в оперативную память (`readAsBytes`) без лимита размера файла (риск OOM / DoS) | Требует исправления |
| **SEC-09** | 🟠 **MEDIUM** | `MASVS-AUTH-3` | Слабая минимальная длина пароля (6 символов) и отсутствие перевыпуска/ротации локальной сессии после смены пароля | Требует исправления |
| **SEC-10** | 🟡 **LOW** | `MASVS-PLATFORM-3` | Отсутствие защиты чувствительных экранов (Финансы, 2FA-секрет) от скриншотов и снимков в меню многозадачности | Рекомендация |
| **SEC-11** | 🟡 **LOW** | `MASVS-STORAGE-2` | Потенциальная утечка заголовков/данных в `FirebaseCrashlytics` и вывод сырого `error.toString()` в UI | Рекомендация |
| **SEC-12** | 🟡 **LOW** | `DevSecOps` | Отсутствие масок для секретов (`env.json`, `*.jks`, `key.properties`) в `.gitignore` и привязка `mock_api_server.mjs` к `0.0.0.0` | Рекомендация |

---

## 2. Детальный разбор уязвимостей

---

### 🔴 [SEC-01] Незашифрованное хранение кэша CRM и тихий фолбэк JWT-токенов в открытый Hive
* **Критичность:** Высокая (High)
* **Категория:** `MASVS-STORAGE-1` (Безопасное хранение чувствительных данных)
* **Затронутые файлы:**
  * [`lib/bootstrap.dart`](lib/bootstrap.dart) (строки 22–26)
  * [`lib/core/network/token_store.dart`](lib/core/network/token_store.dart) (строки 36–75)
  * [`lib/core/cache/response_cache.dart`](lib/core/cache/response_cache.dart) (строки 55–65)

#### Техническое описание
1. **Незашифрованный кэш бизнес-данных:** В `AppBootstrap.initialize()` открываются два бокса Hive без использования `encryptionCipher`:
   ```dart
   final cacheBox = await Hive.openBox<dynamic>('sabt_cache_v1');
   final prefs = await Hive.openBox<dynamic>('sabt_prefs_v1');
   ```
   В бокс `sabt_cache_v1` через `ResponseCache` и `CachedJson` сохраняются до 280 ответов API в виде открытых JSON-строк. Туда попадают:
   * Финансовые сводки, балансы счетов и транзакции (`/finance/overview`);
   * Полная база клиентов/лидов с номерами телефонов и суммами сделок (`/clients`);
   * Персональные данные сотрудников, задачи, внутренние комментарии и журнал безопасности (`/activity-log`).
2. **Silent Fallback (тихий откат) токенов авторизации:** В `TokenStore.load()` и `TokenStore.setTokens()` при возникновении любого исключения при обращении к `FlutterSecureStorage` (например, временная блокировка Android Keystore сразу после перезагрузки устройства до разблокировки экрана или сбой на кастомных прошивках) переменная `_secureAvailable` переводится в `false`, и **`accessToken` вместе с долгоживущим `refreshToken` сохраняются в открытый незашифрованный файл Hive `sabt_prefs_v1`**:
   ```dart
   } catch (error) {
     _secureAvailable = false;
     debugPrint('TokenStore: secure write failed, falling back: $error');
   }
   await _prefs.put(_accessKey, accessToken);
   await _prefs.put(_refreshKey, refreshToken);
   ```
   На Web-платформе этот фолбэк срабатывает всегда, оставляя токены в открытом виде в `IndexedDB` браузера (уязвимо к любому XSS).

#### Рекомендация по устранению
1. Использовать встроенный в `hive_ce` алгоритм шифрования `HiveAesCipher`. Сгенерировать 256-битный ключ через `Hive.generateSecureKey()`, сохранить его в `FlutterSecureStorage` и передавать `encryptionCipher: HiveAesCipher(encryptionKey)` при открытии `sabt_cache_v1` и `sabt_prefs_v1`.
2. На мобильных платформах (`Android` / `iOS`) убрать откат сохранения `accessToken` и `refreshToken` в открытый Hive. Если `Keychain`/`Keystore` временно недоступен, держать токен только в оперативной памяти (`_access`, `_refresh`) до следующего успешного обращения к защищённому хранилищу.
3. В `AndroidOptions` для `FlutterSecureStorage` явно включить `encryptedSharedPreferences: true` (или актуальные настройки `AndroidOptions` в `flutter_secure_storage: ^11.2.0` с `resetOnError: true`).

---

### 🔴 [SEC-02] Отсутствие RBAC-проверок на уровне роутера `GoRouter` и большинства защищённых экранов
* **Критичность:** Высокая (High)
* **Категория:** `MASVS-AUTH-2` (Контроль доступа и маршрутизация)
* **Затронутые файлы:**
  * [`lib/core/router/app_router.dart`](lib/core/router/app_router.dart) (строки 49–196)
  * [`lib/core/navigation/navigation_service.dart`](lib/core/navigation/navigation_service.dart) (строки 35–191)
  * [`lib/features/finance/presentation/finance_page.dart`](lib/features/finance/presentation/finance_page.dart)
  * [`lib/features/access/presentation/employee_access_page.dart`](lib/features/access/presentation/employee_access_page.dart)
  * [`lib/features/security_log/presentation/security_log_page.dart`](lib/features/security_log/presentation/security_log_page.dart)
  * [`lib/features/risks/presentation/risks_page.dart`](lib/features/risks/presentation/risks_page.dart)
  * [`lib/features/analytics/presentation/analytics_page.dart`](lib/features/analytics/presentation/analytics_page.dart)

#### Техническое описание
1. **Отсутствие Route Guards:** В `appRouterProvider` функция `redirect` проверяет только наличие сессии (`session == null`), но не проверяет права доступа (`effectivePermissions` / `userCan`) для конкретного маршрута.
2. **Непоследовательная защита экранов:** В проекте только 2 экрана (`ClientsPage`/`ClientDetailPage` и `EmployeesPage`/`EmployeeDetailPage`) проверяют права внутри `build()` (`if (!canSeeClients(user))`). При этом критически важные экраны:
   * `/finance` (`FinancePage`)
   * `/employee-access` (`EmployeeAccessPage`)
   * `/security-log` (`SecurityLogPage`)
   * `/risks` (`RisksPage`)
   * `/analytics` (`AnalyticsPage`)
   * `/tariffs` (`TariffsPage`)
   * `/dev-board` (`DevBoardPage`)
   **вообще не проверяют права пользователя при рендере**.
3. **Вектор атаки (Push / Deep Link / Web URL):** Любой рядовой сотрудник (например, с ролью `stories_checker` или `employee`) может перейти по маршруту `/finance` или `/employee-access` (через `NavigationService.handleLink` при получении уведомления, либо через адресную строку в Web-сборке). Экран отрендерится, позволит открыть форму создания финансовой транзакции (`TransactionFormSheet`), а при наличии закэшированных данных на общем устройстве — отобразит их.
4. **Мёртвый код (Dead Code) в `NavigationService`:** В `lib/core/navigation/navigation_service.dart` на строках 130–149 стоят условия:
   ```dart
   if (path.startsWith('/risks')) { _push('/risks'); return; }
   if (path.startsWith('/security-log')) { _push('/security-log'); return; }
   if (path.startsWith('/onboarding')) { _push('/onboarding'); return; }
   if (path.startsWith('/employee-access')) { _push('/employee-access'); return; }
   ```
   А ниже, на строке 159, вызывается `if (_isWebOnly(path))`, который проверяет **те же самые префиксы** (`/risks`, `/security-log`, `/employee-access`, `/onboarding`, `/team-activity`). Из-за ранних `return` условие `_isWebOnly(path)` никогда не выполняется.

#### Рекомендация по устранению
1. Добавить централизованную матрицу доступа маршрутов в `redirect` внутри `app_router.dart`:
   * `/finance` → `canSeeFinance(user)`
   * `/employee-access` → `canManageAccess(user)`
   * `/security-log` → `userCan(user, Perm.securityLogView) || user.isTop`
   * `/risks` → `userCan(user, Perm.risksView) || user.isTop`
   * `/analytics` → `userCan(user, Perm.analyticsView)`
   * `/clients*` → `canSeeClients(user)`
   * `/employees*` → `canSeeEmployees(user)`
   При отсутствии права перенаправлять пользователя на `'/'`.
2. Удалить дублирующий мёртвый код `_isWebOnly` в `NavigationService` или привести его в соответствие с актуальным списком нативных экранов.

---

### 🔴 [SEC-03] Бессрочное офлайн-восстановление сессии и логика расчёта разрешений
* **Критичность:** Высокая (High)
* **Категория:** `MASVS-AUTH-1` (Архитектура аутентификации и сессий)
* **Затронутые файлы:**
  * [`lib/features/auth/data/auth_repository.dart`](lib/features/auth/data/auth_repository.dart) (строки 52–83)
  * [`lib/core/rbac/permissions.dart`](lib/core/rbac/permissions.dart) (строки 158–176)

#### Техническое описание
1. **Бессрочный офлайн-доступ:** В `AuthRepository.restore()` при сетевой ошибке (`error.isNetwork`) приложение восстанавливает сессию из `deps.tokens.cachedUser` (`sabt.userSnapshot` из открытого бокса Hive):
   ```dart
   if (error.isNetwork) {
     final cached = deps.tokens.cachedUser;
     if (cached != null) {
       return AuthSession(
         user: UserModel.fromJson(cached),
         restoredOffline: true,
       );
     }
   }
   ```
   У офлайн-сессии отсутствует максимальное время жизни (TTL). Если сотрудник был уволен и заблокирован в CRM, достаточно включить на телефоне «Авиарежим» перед запуском приложения — проверка `/auth/me` выбросит сетевую ошибку, и приложение пустит заблокированного сотрудника внутрь с полным доступом ко всему локальному кэшу (`ResponseCache`).
2. **Отсутствие проверки `user.isActive` и порядок `deniedPermissions` в RBAC:**
   В функции `effectivePermissions(UserModel? user)` (`lib/core/rbac/permissions.dart`):
   * Не проверяется флаг `if (!user.isActive) return const [];`.
   * Имплицитные права (`_implies`) добавляются только для `extraPermissions`, а при удалении `result.removeAll(user.deniedPermissions)` дочерние/связанные права не пересчитываются, и `isSubAdmin` получает все права `admin`, даже если часть прав явно запрещена до этого (хотя `removeAll` идёт после `isSubAdmin`, специальные хелперы вроде `canManageAccess(user)`, `canSeeSmmSection(user)`, `canSeeDevSection(user)` проверяют `user.role` напрямую, **игнорируя** `deniedPermissions`).

#### Рекомендация по устранению
1. Сохранять метку времени последней успешной онлайн-проверки `/auth/me` (в защищённом хранилище) и ограничивать `restoredOffline` разумным окном (например, не более 24–48 часов с момента последнего онлайн-подтверждения).
2. В `effectivePermissions(UserModel? user)` первой строкой добавить `if (user == null || !user.isActive) return const [];`.

---

### 🟠 [SEC-04] Подпись релизной Android-сборки debug-ключом и отсутствие обфускации
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-RESILIENCE-3` / `MASVS-CODE-1`
* **Затронутые файлы:**
  * [`android/app/build.gradle.kts`](android/app/build.gradle.kts) (строки 33–39)

#### Техническое описание
В `android/app/build.gradle.kts` конфигурация релизной сборки использует отладочный ключ:
```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```
Кроме того, в блоке `release` не включены `isMinifyEnabled = true` и `isShrinkResources = true`. Без обфускации (`--obfuscate --split-debug-info`) имена всех классов, методов, репозиториев, моделей и структуры эндпоинтов легко восстанавливаются при декомпиляции `libapp.so` (через `blutter` / `reFlutter`).

#### Рекомендация по устранению
1. Настроить чтение `key.properties` для релизного keystore (с фолбэком на debug только при локальной разработке, если файл `key.properties` отсутствует).
2. Включить `isMinifyEnabled = true` и `isShrinkResources = true` в `buildTypes.release`.
3. В пайплайне сборки зафиксировать флаги:
   ```bash
   flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
   ```

---

### 🟠 [SEC-05] Незаблокированный резервный бэкап данных приложения на Android
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-STORAGE-2` (Предотвращение утечки данных через механизмы ОС)
* **Затронутые файлы:**
  * [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) (строки 6–9)

#### Техническое описание
В теге `<application>` файла `AndroidManifest.xml` отсутствуют атрибуты `android:allowBackup="false"` и `android:fullBackupContent="false"`. По умолчанию Android разрешает резервное копирование директории данных приложения (включая файлы боксов Hive `sabt_cache_v1.hive` и `sabt_prefs_v1.hive`) в облако и через ADB.

#### Рекомендация по устранению
Явно задать в `<application>`:
```xml
android:allowBackup="false"
android:fullBackupContent="false"
```

---

### 🟠 [SEC-06] Рассинхронизация токена в `RealtimeService` и отсутствие принудительного HTTPS/WSS
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-NETWORK-1` (Безопасность сетевых соединений)
* **Затронутые файлы:**
  * [`lib/core/realtime/realtime_service.dart`](lib/core/realtime/realtime_service.dart) (строки 49–62)
  * [`lib/core/network/api_client.dart`](lib/core/network/api_client.dart) (строки 78, 105–111)
  * [`lib/core/config/app_env.dart`](lib/core/config/app_env.dart) (строки 8–35)

#### Техническое описание
1. В `ApiClient` объявлен колбэк `VoidCallback? onTokensRefreshed;`, который вызывается после успешного `/auth/refresh`. Однако в `AppBootstrap` и `AuthController` этот колбэк **никуда не подключён**. Если `accessToken` протух и обновился через `ApiClient`, `RealtimeService` не узнает об этом до следующего реконнекта сокета.
2. В `AppEnv` базовые адреса (`apiBaseUrl`, `wsBaseUrl`, `webBaseUrl`) переопределяются через `--dart-define`. В коде нет runtime-проверки на то, что в релизной сборке (`kReleaseMode`) используются исключительно защищённые схемы `https://` и `wss://`.
3. Дефолтный продакшен-URL захардкожен на технический домен PaaS-провайдера (`https://sabtcrmsystem-production.up.railway.app`), тогда как веб-клиент смотрит на `https://crm.webrand.tj`. При смене хостинга старые клиенты потеряют связь с сервером.

#### Рекомендация по устранению
1. В `AppBootstrap` или `AuthController` подписать `deps.api.onTokensRefreshed` на переподключение/обновление auth-данных сокета в `RealtimeService`.
2. В `AppEnv` добавить assertion/проверку для `kReleaseMode`, блокирующую использование `http://` (кроме локальных dev-сборок).
3. Перевести `API_BASE_URL` и `WS_BASE_URL` на собственный поддомен компании (например, `https://api.webrand.tj`), чтобы не зависеть от домена Railway.

---

### 🟠 [SEC-07] Невалидированный запуск внешних ссылок (`launchUrl`)
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-PLATFORM-2` (Безопасная обработка URI и внешних интентов)
* **Затронутые файлы:**
  * [`lib/features/tasks/presentation/task_detail_page.dart`](lib/features/tasks/presentation/task_detail_page.dart) (строки 213–224)
  * [`lib/features/files/presentation/files_page.dart`](lib/features/files/presentation/files_page.dart) (строки 66–85)
  * [`lib/features/clients/presentation/client_detail_page.dart`](lib/features/clients/presentation/client_detail_page.dart) (строки 39–47, 196–201)
  * [`lib/features/employees/presentation/employee_detail_page.dart`](lib/features/employees/presentation/employee_detail_page.dart) (строки 24–41, 180–198)
  * [`lib/features/misc/presentation/web_only_page.dart`](lib/features/misc/presentation/web_only_page.dart) (строки 17–33)

#### Техническое описание
1. Во всех перечисленных экранах метод открытия ссылки принимает произвольную строку из данных API (например, `file.url`, `result.content`, `client.contactInstagram`, `employee.telegram`) и передаёт её в `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)` без проверки `uri.scheme`.
   * Если в базе окажется ссылка со схемой `javascript:`, `file:`, `intent:` или `content:`, на Web или Android это может привести к выполнению нежелательного действия или открытию системного интента.
   * В `ClientDetailPage` и `EmployeeDetailPage` при проверке `startsWith('http')` допускается любая внешняя ссылка, даже не ведущая на `instagram.com` или `t.me`.
2. В `WebOnlyPage` строка `final url = '${AppEnv.webBaseUrl}$path';` конкатенируется без проверки, что `path` начинается со слэша `/` и не содержит символов `@` или `//`, способных переопределить хост при парсинге URI.

#### Рекомендация по устранению
Создать единый безопасный хелпер `SafeUrlLauncher.open(String rawUrl)`, который:
* Парсит `Uri.tryParse(rawUrl)`;
* Разрешает только белый список схем: `const {'https', 'http', 'tel', 'mailto'}`;
* В `WebOnlyPage` гарантирует, что `path` является относительным путём (`Uri.parse(AppEnv.webBaseUrl).resolveUri(...)` с проверкой совпадения `host`).

---

### 🟠 [SEC-08] Отсутствие контроля размера и типа файлов при выгрузке в память
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-CODE-4` (Валидация входных данных и устойчивость к отказу в обслуживании)
* **Затронутые файлы:**
  * [`lib/features/files/presentation/files_page.dart`](lib/features/files/presentation/files_page.dart) (строки 31–45)
  * [`lib/features/tasks/presentation/task_detail_page.dart`](lib/features/tasks/presentation/task_detail_page.dart) (строки 194–211)
  * [`lib/core/network/api_client.dart`](lib/core/network/api_client.dart) (строки 225–256)

#### Техническое описание
При прикреплении файла к проекту или задаче вызывается:
```dart
final picked = await FilePicker.pickFile();
if (picked == null) return;
final bytes = await picked.readAsBytes();
```
И далее `MultipartFile.fromBytes(bytes, filename: filename)`.
1. Перед вызовом `readAsBytes()` не проверяется размер выбранного файла. Попытка загрузить видеоролик со съёмок (например, 500 МБ – 2 ГБ, что типично для SMM/видеографов агентства) приведёт к выделению сотен мегабайт в куче Dart и аварийному завершению приложения (`OutOfMemoryError`).
2. На стороне клиента не проверяются допустимые расширения/типы файлов.

#### Рекомендация по устранению
1. Проверять размер файла до чтения в память (либо сразу после, если потоковый `length` недоступен на Web), ограничивая его разумным порогом (например, 50 МБ), и показывать понятный `AppBanner` с предупреждением.
2. На мобильных и десктопных платформах использовать потоковую передачу `MultipartFile.fromFile(path)` вместо загрузки всего массива байт в память через `fromBytes`.

---

### 🟠 [SEC-09] Политика паролей и управление сессией при смене пароля
* **Критичность:** Средняя (Medium)
* **Категория:** `MASVS-AUTH-3`
* **Затронутые файлы:**
  * [`lib/features/profile/presentation/profile_page.dart`](lib/features/profile/presentation/profile_page.dart) (строки 86–100, 539–570)
  * [`lib/features/auth/presentation/auth_controller.dart`](lib/features/auth/presentation/auth_controller.dart) (строки 144–151)

#### Техническое описание
1. В форме смены пароля (`_PasswordFormState`) минимальная длина нового пароля составляет всего 6 символов (`if (_new.text.length < 6)`), а также не проверяется совпадение нового пароля со старым (`_new.text == _old.text`).
2. В `AuthController` реализован метод `loginWithPasswordChangedReminder()`, который очищает токены и просит войти заново с новым паролем, однако в `ProfilePage._changePassword()` он **не вызывается** (неиспользуемый метод).

#### Рекомендация по устранению
1. Увеличить минимальную длину пароля минимум до 8 символов и добавить проверку `_new.text != _old.text`.
2. После успешного вызова `changePassword` либо вызывать `authController.loginWithPasswordChangedReminder()`, либо принимать от сервера новую пару `accessToken`/`refreshToken` и обновлять `TokenStore`.

---

### 🟡 [SEC-10] Отсутствие защиты экрана в меню многозадачности (`FLAG_SECURE` / iOS Snapshot)
* **Критичность:** Низкая (Low)
* **Категория:** `MASVS-PLATFORM-3`
* **Затронутые файлы:**
  * [`android/app/src/main/kotlin/com/webbrand/sabt_crm/MainActivity.kt`](android/app/src/main/kotlin/com/webbrand/sabt_crm/MainActivity.kt)
  * [`ios/Runner/AppDelegate.swift`](ios/Runner/AppDelegate.swift)
  * [`lib/features/profile/presentation/profile_page.dart`](lib/features/profile/presentation/profile_page.dart) (строки 746–758)

#### Техническое описание
При сворачивании приложения ОС делает снимок текущего экрана для отображения в списке недавних приложений (App Switcher). Если пользователь свернул приложение на экране «Финансы» (где видны остатки в сейфе и банке) или в момент настройки 2FA (где открытым текстом отображается TOTP-секрет `SelectableText(secret)`), этот снимок сохраняется в файловой системе ОС без шифрования.

#### Рекомендация по устранению
* Скрывать TOTP-секрет под спойлером («Показать ключ вручную») с кнопкой копирования и очисткой буфера обмена через 60 секунд.
* При необходимости высокой конфиденциальности перекрывать экран размытием/сплэшем при переходе `AppLifecycleState.inactive` / `paused`.

---

### 🟡 [SEC-11] Сырые ошибки в UI и фильтрация данных для Crashlytics
* **Критичность:** Низкая (Low)
* **Категория:** `MASVS-STORAGE-2`
* **Затронутые файлы:**
  * [`lib/core/firebase/firebase_bootstrap.dart`](lib/core/firebase/firebase_bootstrap.dart) (строки 77–84)
  * [`lib/features/finance/presentation/finance_page.dart`](lib/features/finance/presentation/finance_page.dart) (строка 67)
  * [`lib/features/files/presentation/files_page.dart`](lib/features/files/presentation/files_page.dart) (строки 57, 175)
  * [`lib/features/access/presentation/employee_access_page.dart`](lib/features/access/presentation/employee_access_page.dart) (строки 58, 113)
  * [`lib/features/security_log/presentation/security_log_page.dart`](lib/features/security_log/presentation/security_log_page.dart) (строка 63)

#### Техническое описание
1. В новых модулях (`FinancePage`, `FilesPage`, `EmployeeAccessPage`, `SecurityLogPage`, `AnalyticsPage`, `RisksPage`) при выводе ошибок используется `error.toString()` вместо проверки `error is ApiException ? error.message : 'Произошла ошибка'`. Из-за этого в UI пользователю выводится технический префикс `ApiException(403): ...` или внутреннее описание исключения Dart.
2. В `SettingsPage` (строки 261–305) в разделе «Диагностика» любому авторизованному пользователю отображаются внутренние инфраструктурные детали: полный URL сервера API (`AppEnv.apiOrigin`), `wsNamespaceUrl`, статус Keystore и `firebaseProjectId`.

#### Рекомендация по устранению
1. Унифицировать отображение текста ошибок через единый геттер/хелпер (как это сделано в `TaskDetailPage._showError`).
2. Скрыть технические адреса серверов и идентификатор проекта Firebase в `SettingsPage` для обычных ролей (оставить только для `admin`/`founder` или `kDebugMode`).

---

### 🟡 [SEC-12] Безопасность репозитория (`.gitignore`) и локального mock-сервера
* **Критичность:** Низкая (Low / DevSecOps)
* **Затронутые файлы:**
  * [`.gitignore`](.gitignore)
  * [`tool/mock_api_server.mjs`](tool/mock_api_server.mjs) (строки 1006, 1076)

#### Техническое описание
1. В комментарии к [`lib/core/config/app_env.dart`](lib/core/config/app_env.dart) рекомендуется использовать `--dart-define-from-file=env.json`, однако в `.gitignore` **не добавлены** паттерны для файлов конфигурации и ключей подписи:
   * `env.json`, `.env*`, `*.env`
   * `android/key.properties`, `*.jks`, `*.keystore`
   * `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`
   Это создаёт риск случайной публикации секретов и ключей подписи в системе контроля версий.
2. В `tool/mock_api_server.mjs` вызов `server.listen(PORT)` без указания хоста привязывает сервер ко всем сетевым интерфейсам (`0.0.0.0`), открывая доступ к локальному mock-серверу и статике `build/web` для всех устройств в той же локальной/Wi-Fi сети.

#### Рекомендация по устранению
1. Дополнить `.gitignore` правилами игнорирования секретов (`env*.json`, `.env*`, `key.properties`, `*.jks`, `*.keystore`).
2. В `tool/mock_api_server.mjs` изменить запуск на `server.listen(PORT, '127.0.0.1', ...)`.

---

## 3. Дорожная карта исправлений (Action Plan)

1. **Шаг 1 (Быстрые победы — 30 минут):**
   * Обновить `.gitignore` (добавить `env*.json`, `key.properties`, `*.jks`, `*.keystore`).
   * В `AndroidManifest.xml` добавить `android:allowBackup="false"` и `android:fullBackupContent="false"`.
   * Ограничить `tool/mock_api_server.mjs` интерфейсом `127.0.0.1`.
2. **Шаг 2 (Защита данных и сессии — 2–3 часа):**
   * Внедрить `HiveAesCipher` с ключом из `FlutterSecureStorage` для `sabt_cache_v1` и `sabt_prefs_v1`.
   * Убрать запись `accessToken`/`refreshToken` в незашифрованный Hive при ошибках `FlutterSecureStorage` на мобильных ОС.
   * Ограничить время жизни офлайн-сессии (`restoredOffline`) и добавить проверку `user.isActive` в `effectivePermissions`.
   * Подключить `api.onTokensRefreshed` к `RealtimeService`.
3. **Шаг 3 (Контроль доступа и маршрутизация — 1–2 часа):**
   * Добавить проверку прав (`userCan`) в `redirect` `GoRouter` для всех административных и ролевых маршрутов.
   * Очистить мёртвый код `_isWebOnly` в `NavigationService` и добавить валидатор схем для `launchUrl`.
   * Добавить проверку максимального размера файла перед вызовом `readAsBytes()`.
4. **Шаг 4 (Релизный пайплайн — 1 час):**
   * Настроить релизную подпись Android в `build.gradle.kts`, включить R8 и сборку с `--obfuscate`.
