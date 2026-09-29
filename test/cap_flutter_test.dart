import 'package:cap_flutter/cap_flutter.dart';
import 'package:cap_flutter/src/html_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildCapHtml', () {
    test('builds a headless solver page exposing solve/reset helpers', () {
      final html = buildCapHtml(apiEndpoint: 'https://cap.example.com/abc123/');

      expect(html, contains('__capSolve'));
      expect(html, contains('__capReset'));
      expect(html, contains(kCapEventHandler));
      expect(html, contains('apiEndpoint'));
    });

    test('loads the widget bundle via a classic script tag', () {
      // WKWebView rejects remote module imports in loadData pages, so the
      // UMD bundle must be loaded with a <script> element rather than
      // `await import(url)`.
      final html = buildCapHtml(apiEndpoint: 'https://cap.example.com/abc123/');

      expect(html, contains("document.createElement('script')"));
      expect(html, contains('window.Cap'));
      expect(html, isNot(contains('await import(')));
    });

    test('embeds the worker count in solve options', () {
      final html = buildCapHtml(
        apiEndpoint: 'https://cap.example.com/abc123/',
        workerCount: 4,
      );

      expect(html, contains('workers: 4'));
    });

    test('sets custom WASM URLs as CAP_* globals', () {
      final html = buildCapHtml(
        apiEndpoint: 'https://cap.example.com/abc123/',
        wasmUrl: 'https://cap.example.com/assets/cap_wasm_bg.wasm',
        hashwxUrl: 'https://cap.example.com/assets/hashwx.wasm',
      );

      expect(
        html,
        contains(
          'window.CAP_CUSTOM_WASM_URL="https://cap.example.com/assets/cap_wasm_bg.wasm"',
        ),
      );
      expect(
        html,
        contains(
          'window.CAP_CUSTOM_HASHWX_URL="https://cap.example.com/assets/hashwx.wasm"',
        ),
      );
    });

    test('emits the webview_too_old preflight in ES5 syntax', () {
      final html = buildCapHtml(apiEndpoint: 'https://cap.example.com/abc123/');

      expect(html, contains('webview_too_old'));
      expect(html, contains('WebAssembly'));
    });
  });

  group('CapError', () {
    test('parses message and code from event detail', () {
      final error = CapError.fromEventDetail({
        'message': 'redeem failed',
        'code': 'redeem_failed',
      });

      expect(error.message, 'redeem failed');
      expect(error.code, 'redeem_failed');
    });

    test('handles missing detail', () {
      final error = CapError.fromEventDetail(null);
      expect(error.message, isNotEmpty);
      expect(error.code, isNull);
    });
  });
}
