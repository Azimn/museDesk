import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, chmodSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { discoverMusePath, getMuseVersion, resolveViaLoginShell } from '../../src/msp/discovery';

const isWindows = process.platform === 'win32';

// Hermetic: every case uses stub executables under a temp dir, so the
// machine's real `muse` install, or lack of one, cannot affect results.
describe('muse discovery', () => {
  let dir = '';
  let stubBin = '';
  let fakeShell = '';

  function makeMuseStub(root: string, label: string): string {
    const file = path.join(root, isWindows ? 'muse.cmd' : 'muse');
    if (isWindows) {
      writeFileSync(file, `@echo off\r\necho Muse Code ${label} (stub)\r\n`);
    } else {
      writeFileSync(file, `#!/bin/sh\necho "Muse Code ${label} (stub)"\n`);
      chmodSync(file, 0o755);
    }
    return file;
  }

  before(() => {
    dir = mkdtempSync(path.join(tmpdir(), 'muse-disc-'));
    stubBin = makeMuseStub(dir, '9.9.9');
    if (!isWindows) {
      fakeShell = path.join(dir, 'fakeshell');
      writeFileSync(fakeShell, `#!/bin/sh\necho ${stubBin}\n`);
      chmodSync(fakeShell, 0o755);
    }
  });

  after(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it('finds muse on the given PATH and reads its version', () => {
    assert.equal(discoverMusePath(dir), stubBin);
    assert.equal(getMuseVersion(stubBin), 'Muse Code 9.9.9 (stub)');
  });

  it('resolves via the login shell when PATH misses, validating executability', { skip: isWindows }, () => {
    assert.equal(resolveViaLoginShell(fakeShell), stubBin);
    const lyingShell = path.join(dir, 'lyingshell');
    writeFileSync(lyingShell, '#!/bin/sh\necho "/does/not/exist"\n');
    chmodSync(lyingShell, 0o755);
    assert.equal(resolveViaLoginShell(lyingShell), null);
    const failingShell = path.join(dir, 'failshell');
    writeFileSync(failingShell, '#!/bin/sh\nexit 1\n');
    chmodSync(failingShell, 0o755);
    assert.equal(resolveViaLoginShell(failingShell), null);
  });

  it('prefers the first PATH entry that holds a runnable muse', () => {
    const dir2 = mkdtempSync(path.join(tmpdir(), 'muse-disc2-'));
    try {
      const stub2 = makeMuseStub(dir2, '8.8.8');
      assert.equal(discoverMusePath(`${dir2}${path.delimiter}${dir}`), stub2);
      assert.equal(discoverMusePath(`${dir}${path.delimiter}${dir2}`), stubBin);
    } finally {
      rmSync(dir2, { recursive: true, force: true });
    }
  });

  it('resolves the native Windows command launcher to its versioned executable', () => {
    const win = mkdtempSync(path.join(tmpdir(), 'muse-win-layout-'));
    try {
      const launcher = path.join(win, 'muse.cmd');
      const version = '1.4.2-R4684.1';
      const payload = path.join(win, `muse-bin-${version}.exe`);
      writeFileSync(launcher, '@echo off\r\n');
      writeFileSync(path.join(win, '.muse-version'), `${version}\r\n`);
      writeFileSync(payload, 'fake-pe');
      assert.equal(
        discoverMusePath(win, { platform: 'win32', env: {} }),
        payload,
      );
    } finally {
      rmSync(win, { recursive: true, force: true });
    }
  });

  it('uses the native Windows local-app-data install location when PATH misses', () => {
    const local = mkdtempSync(path.join(tmpdir(), 'muse-localappdata-'));
    try {
      const install = path.join(local, 'Programs', 'muse');
      mkdirSync(install, { recursive: true });
      const launcher = path.join(install, 'muse.cmd');
      writeFileSync(launcher, '@echo off\r\n');
      assert.equal(
        discoverMusePath('', { platform: 'win32', env: { LOCALAPPDATA: local } }),
        launcher,
      );
    } finally {
      rmSync(local, { recursive: true, force: true });
    }
  });
});
