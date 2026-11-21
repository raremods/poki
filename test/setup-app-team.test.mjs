// Which Developer ID team the installer trusts for Qeno Setup. Qeno Setup is signed by
// Uncut Rush LLC, team AJ9G5DH5ZQ; the installer has to accept that team, and nothing else.
//
// The first two tests run everywhere. The rest run verifyApp for real (codesign and spctl), so they need a
// Mac; the signed disk images are too large and too private to keep in the repository, so point the
// environment at them:
//   POKI_TEST_SETUP_DMG_NEW=<QenoSetup-*-macos.dmg>   signed by AJ9G5DH5ZQ
//   POKI_TEST_OTHER_TEAM_APP=<a notarized .app from any other Developer ID team>   (optional)
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { cp, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';
import * as installer from '../src/install/setup-app.mjs';

const exec = promisify(execFile);
const mac = process.platform === 'darwin';

const signing = team => `Identifier=nz.zheha.poki.setup\nAuthority=Developer ID Application: Someone\nTeamIdentifier=${team}\nTimestamp=Nov 15, 2026\n`;

test('Qeno\'s Developer ID team is trusted', () => {
  assert.deepEqual([...(installer.TEAM_IDS ?? [])].sort(), ['AJ9G5DH5ZQ']);
  assert.equal(installer.pokiTeamOf(signing('AJ9G5DH5ZQ')), 'AJ9G5DH5ZQ');
});

test('any other team, an unsigned team, or a look-alike is not trusted', () => {
  for (const team of ['ZZZZZZZZZZ', 'not set', '', 'AJ9G5DH5ZQX', 'XAJ9G5DH5ZQ', 'aj9g5dh5zq', 'AJ9G5DH5ZQ Q64ZL36CJN']) {
    assert.equal(installer.pokiTeamOf(signing(team)), null, team);
  }
  assert.equal(installer.pokiTeamOf('Identifier=x\nAuthority=Developer ID Application: Someone (AJ9G5DH5ZQ)\n'), null, 'a team named in an authority line is not the TeamIdentifier');
  assert.equal(installer.pokiTeamOf(''), null);
});

async function withMounted(dmg, run) {
  const mount = await mkdtemp(join(tmpdir(), 'poki-team-test-'));
  await exec('hdiutil', ['attach', '-nobrowse', '-readonly', '-noautoopen', '-mountpoint', mount, dmg]);
  try { return await run(join(mount, 'Poki Setup.app')); }
  finally { await exec('hdiutil', ['detach', mount, '-quiet']).catch(() => exec('hdiutil', ['detach', mount, '-force', '-quiet'])); await rm(mount, { recursive: true, force: true }); }
}

const newDmg = process.env.POKI_TEST_SETUP_DMG_NEW;
const otherApp = process.env.POKI_TEST_OTHER_TEAM_APP;

test('verifyApp accepts Qeno Setup signed by the team (AJ9G5DH5ZQ)', { skip: !mac ? 'needs macOS' : !newDmg ? 'POKI_TEST_SETUP_DMG_NEW is not set' : false }, async () => {
  await withMounted(newDmg, installer.verifyApp);
});

test('verifyApp rejects a notarized app from another team', { skip: !mac ? 'needs macOS' : !otherApp ? 'POKI_TEST_OTHER_TEAM_APP is not set' : false }, async () => {
  await assert.rejects(installer.verifyApp(otherApp), error => error.code === 'setup_signature_invalid' && /not signed by team AJ9G5DH5ZQ/.test(error.message));
});

test('verifyApp rejects an app that has no team at all', { skip: mac ? false : 'needs macOS' }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'poki-team-test-'));
  try {
    const app = join(dir, 'Poki Setup.app');
    await mkdir(join(app, 'Contents/MacOS'), { recursive: true });
    await cp('/usr/bin/true', join(app, 'Contents/MacOS/PokiSetup'));
    await writeFile(join(app, 'Contents/Info.plist'), '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>PokiSetup</string><key>CFBundleIdentifier</key><string>test.poki.setup</string></dict></plist>');
    await exec('codesign', ['--force', '-s', '-', app]);
    await assert.rejects(installer.verifyApp(app), error => error.code === 'setup_signature_invalid' && /not signed by team/.test(error.message));
  } finally { await rm(dir, { recursive: true, force: true }); }
});
