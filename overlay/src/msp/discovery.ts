import { spawnSync } from 'node:child_process';
import { statSync, readFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { probeCliArch, type CliArchKind } from './arch';

export interface MuseInstall {
  binPath: string;
  version: string;
  /** CPU slices the CLI binary was built for ('unknown' when undetectable). */
  arch: CliArchKind;
}

interface DiscoveryOptions {
  platform?: NodeJS.Platform;
  env?: NodeJS.ProcessEnv;
}

const VERSION_PATTERN = /^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$/;

function isRunnableFile(file: string, platform = process.platform): boolean {
  try {
    const st = statSync(file);
    if (!st.isFile()) return false;
    return platform === 'win32' || (st.mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

/**
 * The official Windows installer currently exposes a muse.cmd launcher beside
 * .muse-version and muse-bin-<version>.exe. Prefer the real executable so Node
 * can spawn the CLI without involving cmd.exe. If the layout changes, keep the
 * launcher itself as a supported fallback.
 */
function resolveWindowsLauncher(file: string, platform = process.platform): string {
  if (platform !== 'win32' || !/\.(cmd|bat)$/i.test(file)) return file;
  const dir = path.dirname(file);
  try {
    const version = readFileSync(path.join(dir, '.muse-version'), 'utf8')
      .trim()
      .split(/\r?\n/)[0]
      .trim();
    if (VERSION_PATTERN.test(version)) {
      const payload = path.join(dir, `muse-bin-${version}.exe`);
      if (isRunnableFile(payload, platform)) return payload;
    }
  } catch {
    /* use the command wrapper */
  }
  return file;
}

/**
 * Ask the user's login shell where `muse` resolves. Packaged GUI apps do not
 * inherit the login-shell PATH on macOS, so this finds user-local installs.
 * Windows does not use this path because Muse Code has a native installation.
 */
export function resolveViaLoginShell(
  shell = process.env.SHELL || '/bin/zsh',
  platform: NodeJS.Platform = process.platform,
): string | null {
  if (platform === 'win32') return null;
  try {
    const r = spawnSync(shell, ['-l', '-c', 'command -v muse'], {
      encoding: 'utf8',
      timeout: 10000,
    });
    if (r.status !== 0) return null;
    const found = (r.stdout || '').trim().split('\n')[0]?.trim() ?? '';
    if (found !== '' && !found.includes('\n') && isRunnableFile(found, platform)) return found;
  } catch {
    /* fall through */
  }
  return null;
}

function windowsCandidates(dir: string): string[] {
  return ['muse.exe', 'muse.cmd', 'muse.bat', 'muse'].map((name) => path.join(dir, name));
}

/**
 * Find the official `muse` CLI. MuseDesk never bundles or downloads a CLI
 * binary. On Windows, the native Meta installer location is checked in
 * addition to PATH. On macOS and Linux, the existing POSIX lookup remains.
 */
export function discoverMusePath(
  envPath = process.env.PATH ?? '',
  opts: DiscoveryOptions = {},
): string {
  const platform = opts.platform ?? process.platform;
  const env = opts.env ?? process.env;

  const explicit = env.MUSE_CLI?.trim();
  if (explicit && path.isAbsolute(explicit) && isRunnableFile(explicit, platform)) {
    return resolveWindowsLauncher(explicit, platform);
  }

  for (const dir of envPath.split(path.delimiter)) {
    if (!dir) continue;
    const candidates = platform === 'win32' ? windowsCandidates(dir) : [path.join(dir, 'muse')];
    for (const candidate of candidates) {
      if (isRunnableFile(candidate, platform)) return resolveWindowsLauncher(candidate, platform);
    }
  }

  const home = os.homedir();
  if (platform === 'win32') {
    const roots = [env.MUSE_INSTALL_DIR, env.LOCALAPPDATA ? path.join(env.LOCALAPPDATA, 'Programs', 'muse') : null]
      .filter((v): v is string => typeof v === 'string' && v.trim() !== '');
    for (const root of roots) {
      for (const candidate of windowsCandidates(root)) {
        if (isRunnableFile(candidate, platform)) return resolveWindowsLauncher(candidate, platform);
      }
    }
    throw new Error(
      'muse CLI not found. Install the official Muse Code CLI in PowerShell with "irm https://dev.meta.ai/install.ps1 | iex", then restart MuseDesk.',
    );
  }

  for (const candidate of [
    path.join(home, '.local', 'bin', 'muse'),
    '/opt/homebrew/bin/muse',
    '/usr/local/bin/muse',
  ]) {
    if (isRunnableFile(candidate, platform)) return candidate;
  }
  const viaShell = resolveViaLoginShell(env.SHELL || '/bin/zsh', platform);
  if (viaShell) return viaShell;
  throw new Error(
    'muse CLI not found on PATH. Install the official Muse Code CLI first; MuseDesk will not bundle or fetch one.',
  );
}

export function getMuseVersion(binPath: string): string {
  const isWindowsWrapper = process.platform === 'win32' && /\.(cmd|bat)$/i.test(binPath);
  const r = spawnSync(binPath, ['--version'], {
    encoding: 'utf8',
    timeout: 10000,
    windowsHide: true,
    shell: isWindowsWrapper,
  });
  if (r.status !== 0) throw new Error(`muse --version failed: ${(r.stderr || '').slice(0, 300)}`);
  return (r.stdout || '').trim().split(/\r?\n/)[0];
}

export function discoverMuse(): MuseInstall {
  const binPath = discoverMusePath();
  return { binPath, version: getMuseVersion(binPath), arch: probeCliArch(binPath) };
}

/** Pinned expectations generated from the CLI this build was verified against. */
export function readPinned(dir: string): { cliVersion: string; fingerprint: string } {
  return {
    cliVersion: readFileSync(path.join(dir, 'CLI_VERSION.txt'), 'utf8').trim(),
    fingerprint: readFileSync(path.join(dir, 'FINGERPRINT.txt'), 'utf8').trim(),
  };
}
