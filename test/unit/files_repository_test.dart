import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sabt_crm/core/cache/response_cache.dart';
import 'package:sabt_crm/core/network/api_client.dart';
import 'package:sabt_crm/core/network/api_exception.dart';
import 'package:sabt_crm/core/network/token_store.dart';
import 'package:sabt_crm/features/files/data/files_repository.dart';
import 'package:sabt_crm/features/files/presentation/files_providers.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late ResponseCache cache;

  Map<String, dynamic> fileJson(String id, String name) => {
    'id': id,
    'name': name,
    'url': '/uploads/$name',
    'size': 2048,
  };

  FilesRepository repoWith(Future<dynamic> Function(String path) handler) {
    return FilesRepository.direct(
      api: _FakeApiClient(TokenStore(box), handler),
      cache: cache,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sabt_files_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('test_cache');
    cache = ResponseCache(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('FilesRepository.watchFilesByProject', () {
    test(
      'emits the cached snapshot first, then the fresh network list',
      () async {
        await cache.write('files.project.p1', {
          'data': [fileJson('1', 'old.pdf')],
        });
        final repo = repoWith((path) async {
          expect(path, '/files/project/p1');
          return {
            'data': [fileJson('1', 'old.pdf'), fileJson('2', 'new.pdf')],
          };
        });

        final events = await repo.watchFilesByProject('p1').toList();

        expect(events, hasLength(2));
        expect(events.first.map((f) => f.name), ['old.pdf']);
        expect(events.last.map((f) => f.name), ['old.pdf', 'new.pdf']);
      },
    );

    test('writes the network response through to the cache', () async {
      final repo = repoWith(
        (_) async => {
          'data': [fileJson('7', 'fresh.pdf')],
        },
      );

      await repo.watchFilesByProject('p9').toList();

      final cached = cache.read('files.project.p9');
      expect(cached, isNotNull);
      // A second watch must now serve the fresh snapshot from disk first.
      final failingRepo = repoWith(
        (_) async => throw const ApiException('down'),
      );
      final events = await failingRepo.watchFilesByProject('p9').toList();
      expect(events.single.map((f) => f.name), ['fresh.pdf']);
    });

    test(
      'keeps the cached list and completes when the refresh fails',
      () async {
        await cache.write('files.project.p2', {
          'data': [fileJson('3', 'cached.pdf')],
        });
        final repo = repoWith((_) async => throw const ApiException('offline'));

        final events = await repo.watchFilesByProject('p2').toList();

        expect(events.single.map((f) => f.name), ['cached.pdf']);
      },
    );

    test('surfaces the error when there is no cache to fall back on', () async {
      final repo = repoWith((_) async => throw const ApiException('offline'));

      await expectLater(
        repo.watchFilesByProject('nope'),
        emitsError(isA<ApiException>()),
      );
    });

    test('accepts a bare list payload as well as a wrapped one', () async {
      final repo = repoWith((_) async => [fileJson('5', 'bare.pdf')]);

      final events = await repo.watchFilesByProject('p5').toList();

      expect(events.last.single.name, 'bare.pdf');
    });
  });

  group('projectFilesProvider', () {
    test(
      'serves the cache through Riverpod before the network lands',
      () async {
        await cache.write('files.project.p1', {
          'data': [fileJson('1', 'old.pdf')],
        });
        final repo = repoWith((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return {
            'data': [fileJson('2', 'new.pdf')],
          };
        });
        final container = ProviderContainer(
          overrides: [filesRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final seen = <List<String>>[];
        final sub = container.listen(projectFilesProvider('p1'), (_, next) {
          final value = next.value;
          if (value != null) seen.add(value.map((f) => f.name).toList());
        }, fireImmediately: true);
        addTearDown(sub.close);

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(seen.first, ['old.pdf']);
        expect(seen.last, ['new.pdf']);
      },
    );
  });

  group('FilesRepository.getFilesByProject (explicit refresh)', () {
    test('returns network data and falls back to cache on failure', () async {
      final repo = repoWith(
        (_) async => {
          'data': [fileJson('8', 'net.pdf')],
        },
      );
      final files = await repo.getFilesByProject('p8');
      expect(files.single.name, 'net.pdf');

      final failing = repoWith((_) async => throw const ApiException('down'));
      final fromCache = await failing.getFilesByProject('p8');
      expect(fromCache.single.name, 'net.pdf');
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(TokenStore tokens, this._handler) : super(tokens: tokens);

  final Future<dynamic> Function(String path) _handler;

  @override
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _handler(path);
}
