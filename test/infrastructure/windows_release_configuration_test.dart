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

    test('the Store manifest declares the narrow desktop contract', () {
      final manifest = source('windows/store/AppxManifest.xml');

      expect(manifest, contains('ProcessorArchitecture="x64"'));
      expect(manifest, contains('Name="Windows.Desktop"'));
      expect(manifest, contains('MinVersion="10.0.19041.0"'));
      expect(manifest, contains('Executable="visualmd.exe"'));
      expect(manifest, contains('uap10:RuntimeBehavior="packagedClassicApp"'));
      expect(manifest, contains('uap10:TrustLevel="mediumIL"'));
      expect(manifest, contains('rescap:Capability Name="runFullTrust"'));
      expect(manifest, isNot(contains('broadFileSystemAccess')));
      expect(manifest, isNot(contains('internetClient')));
    });

    test('production packaging requires the Partner Center identity', () {
      final packager = source('bin/tools/package-windows-store.ps1');

      expect(packager, contains(r'[Parameter(Mandatory = $true)]'));
      expect(packager, contains(r'[string]$IdentityName'));
      expect(packager, contains(r'[string]$Publisher'));
      expect(packager, contains(r'[string]$PublisherDisplayName'));
      expect(packager, contains('makeappx.exe'));
      expect(packager, contains('/h SHA256'));
      expect(packager, contains('| Out-Host'));
      expect(packager, contains(r'$packageVersion = "$appVersion.0"'));
      expect(packager, isNot(contains('Azure')));
      expect(packager, isNot(contains('Inno')));
    });

    test('ordinary CI builds and audits an unpublished Store package', () {
      final workflow = source('.github/workflows/validate.yml');

      expect(workflow, contains('runs-on: windows-2025'));
      expect(workflow, contains('flutter test'));
      expect(workflow, contains('flutter build windows --release'));
      expect(workflow, contains('validate-windows-bundle.ps1'));
      expect(workflow, contains('package-windows-store.ps1'));
      expect(workflow, contains('validate-windows-store-package.ps1'));
      expect(workflow, contains('IdentityName VisualMD.CI'));
      expect(workflow, isNot(contains('upload-artifact')));
      expect(workflow, isNot(contains('gh release')));
    });

    test('the package audit keeps runtime and Store assets together', () {
      final validator = source('bin/tools/validate-windows-store-package.ps1');

      for (final required in [
        'visualmd.exe',
        'flutter_windows.dll',
        r'data\app.so',
        'AssetManifest.bin',
        'FontManifest.json',
        'NOTICES.Z',
        'StoreLogo.png',
        'Square44x44Logo.png',
        'Square150x150Logo.png',
        'Square44x44Logo.targetsize-16.png',
        'Square44x44Logo.targetsize-256.png',
        'Square150x150Logo.scale-400.png',
        'runFullTrust',
        'packagedClassicApp',
        'mediumIL',
      ]) {
        expect(validator, contains(required));
      }
    });

    test('the local smoke test removes its package and certificates', () {
      final smokeTest = source('bin/tools/test-windows-store-package.ps1');

      expect(smokeTest, contains('New-SelfSignedCertificate'));
      expect(smokeTest, contains('StoreName]::Root'));
      expect(smokeTest, contains('StoreLocation]::CurrentUser'));
      expect(smokeTest, contains('not Local System'));
      expect(smokeTest, contains('Add-AppxPackage'));
      expect(smokeTest, contains('Remove-AppxPackage'));
      expect(smokeTest, contains('shell:AppsFolder'));
      expect(smokeTest, contains('appcert.exe'));
    });
  });
}
