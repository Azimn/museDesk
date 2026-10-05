// Build-only shim loaded through NODE_OPTIONS when the Electron template is extracted.
// extract-zip@2 can exit early on Node 26. Use an operating-system extractor for
// this one operation, while leaving every other module load unchanged.
'use strict';

const { execFileSync } = require('node:child_process');
const Module = require('node:module');

const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'extract-zip') {
    return async (src, opts) => {
      if (process.platform === 'win32') {
        execFileSync(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Expand-Archive -LiteralPath $env:MUSEDESK_ZIP_SRC -DestinationPath $env:MUSEDESK_ZIP_DST -Force',
          ],
          {
            stdio: 'pipe',
            env: {
              ...process.env,
              MUSEDESK_ZIP_SRC: src,
              MUSEDESK_ZIP_DST: opts.dir,
            },
          },
        );
      } else {
        execFileSync('unzip', ['-q', '-o', src, '-d', opts.dir], { stdio: 'pipe' });
      }
    };
  }
  return origLoad.call(this, request, parent, isMain);
};
