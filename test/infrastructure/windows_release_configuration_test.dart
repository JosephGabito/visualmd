import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  group('the Windows release contract', () {
    test(
      'the host opens at the measured desktop size without a menu strip',
      () {
        final main = source('windows/runner/main.cpp');
        final window = source('windows/runner/flutter_window.cpp');

        expect(main, contains('Win32Window::Size size(1280, 800)'));
        expect(window, isNot(contains('CreateMenu')));
        expect(window, isNot(contains('SetMenu')));
        expect(window, isNot(contains('L"File"')));
      },
    );

    test('the native caption follows the active Visual MD chrome', () {
      final window = source('windows/runner/flutter_window.cpp');

      expect(window, contains('updateWindowChrome'));
      expect(window, contains('DWMWA_CAPTION_COLOR'));
      expect(window, contains('DWMWA_TEXT_COLOR'));
      expect(window, contains('ColorRefFromArgb'));
    });

    test('the installer carries the complete bundle without elevation', () {
      final installer = source('windows/installer/visualmd.iss');

      expect(installer, contains('PrivilegesRequired=lowest'));
      expect(installer, contains('ArchitecturesAllowed=x64compatible'));
      expect(installer, contains(r'DefaultDirName={localappdata}'));
      expect(installer, contains(r'Source: "{#SourceDir}\*"'));
      expect(installer, contains('recursesubdirs createallsubdirs'));
      expect(installer, contains(r'Filename: "{app}\visualmd.exe"'));
      expect(installer, contains('SignTool=visualmd'));
      expect(installer, contains('SignedUninstaller=yes'));
      expect(installer, contains('[InstallDelete]'));
      expect(installer, contains(r'Name: "{app}\*.dll"'));
    });

    test('tagged releases cannot publish unsigned artifacts', () {
      final workflow = source('.github/workflows/release-windows.yml');

      expect(workflow, contains('tags: ["v*.*.*"]'));
      expect(workflow, contains('azure/login@'));
      expect(workflow, contains('Azure/artifact-signing-action@'));
      expect(workflow, contains('AZURE_ARTIFACT_SIGNING_ENDPOINT'));
      expect(workflow, contains('environment: windows-release'));
      expect(workflow, contains('WINDOWS_SIGNER_SUBJECT'));
      expect(workflow, contains("github.event_name == 'push'"));
      expect(workflow, contains('persist-credentials: false'));
      expect(workflow, contains('-RequireSignature'));
      expect(workflow, contains('test-windows-installer.ps1'));
      expect(workflow, contains('actions/attest@'));
      expect(workflow, contains('gh release create'));
      expect(workflow, contains('--draft'));
      expect(workflow, contains('gh release edit'));
      expect(workflow, isNot(contains('--clobber')));
      expect(workflow, contains(r'Release $env:RELEASE_TAG already exists'));
      expect(
        workflow,
        contains(r'release $env:RELEASE_TAG remains a private draft'),
      );
    });

    test('ordinary CI compiles and audits on a Windows host', () {
      final workflow = source('.github/workflows/validate.yml');

      expect(workflow, contains('runs-on: windows-2025'));
      expect(workflow, contains('flutter test'));
      expect(workflow, contains('flutter build windows --release'));
      expect(workflow, contains('validate-windows-bundle.ps1'));
      expect(workflow, contains('steps.version.outputs.value'));
    });

    test('the bundle audit keeps runtime and licence assets together', () {
      final validator = source('bin/tools/validate-windows-bundle.ps1');

      for (final required in [
        'visualmd.exe',
        'flutter_windows.dll',
        r'data\app.so',
        'AssetManifest.bin',
        'FontManifest.json',
        'NOTICES.Z',
        'LICENSE-*.txt',
        '*-THIRD_PARTY_NOTICES.md',
        'TimeStamperCertificate',
        'ExpectedSignerSubject',
      ]) {
        expect(validator, contains(required));
      }
    });

    test('the lifecycle smoke test refuses an existing installation', () {
      final smokeTest = source('bin/tools/test-windows-installer.ps1');

      expect(smokeTest, contains('Visual MD is already installed'));
      expect(smokeTest, contains('E1875246-B154-4B31-A75A-4D65902E05F5'));
      expect(smokeTest, contains(r'Test-Path -LiteralPath $installDirectory'));
    });
  });
}
