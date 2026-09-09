"""Exercise dispatch in disposable fish processes; never launch real GUI apps."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).with_name('fopen.fish').resolve()


class OpenTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.apps = self.root / 'applications'
        self.apps.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'args'
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root),
                        XDG_DATA_DIRS=str(self.root),
                        PATH=f'{self.bin}:' + os.environ['PATH'],
                        OPEN_LOG=str(self.log))
        self.stub('editor', 'printf "%s\\n" "$@" > "$OPEN_LOG"')
        self.stub('gtk-launch', 'printf "%s\\n" "$@" > "$OPEN_LOG"; exit "${LAUNCH_STATUS:-0}"')
        self.desktop('terminal', 'Terminal=true\nExec=editor "fixed argument" %F\n')
        self.desktop('gui', 'Exec=unused %F\n')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body + '\n')
        path.chmod(0o755)

    def desktop(self, name, body):
        (self.apps / (name + '.desktop')).write_text('[Desktop Entry]\nType=Application\nName=Test\n' + body)

    def run_option(self, option):
        return subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _open_file_with_option "$argv[2]" "$argv[3]"; '
            'set result $status; echo shell-alive; exit $result',
            str(SOURCE), option, '/tmp/file with spaces.txt'],
            env=self.env, capture_output=True, text=True)

    def test_terminal_preserves_shell_and_arguments(self):
        result = self.run_option('desktop:terminal.desktop')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('shell-alive', result.stdout)
        self.assertEqual(self.log.read_text().splitlines(),
                         ['fixed argument', '/tmp/file with spaces.txt'])

    def test_gui_exits_shell(self):
        result = self.run_option('desktop:gui.desktop')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('shell-alive', result.stdout)
        self.assertEqual(self.log.read_text().splitlines(),
                         ['gui.desktop', '/tmp/file with spaces.txt'])

    def test_launch_failure_keeps_shell(self):
        self.env['LAUNCH_STATUS'] = '1'
        result = self.run_option('desktop:gui.desktop')
        self.assertEqual(result.returncode, 1)
        self.assertIn('shell-alive', result.stdout)

    def test_default_terminal_preserves_shell(self):
        self.stub('gio', 'echo "Default application for text/plain: terminal.desktop"')
        result = self.run_option('default:gio')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('shell-alive', result.stdout)
        self.assertEqual(self.log.read_text().splitlines()[-1], '/tmp/file with spaces.txt')

    def test_catalog_supplements_associations_without_duplicate_executables(self):
        self.stub('code', 'exit 0')
        self.stub('nvim', 'exit 0')
        self.desktop('neovim', 'Terminal=true\nExec=env EDITOR_MODE=1 /usr/bin/nvim %F\n')
        self.stub('gio', 'echo "Default application for text/plain: neovim.desktop"')
        result = subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _fopen_app_options text/plain', str(SOURCE)],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('desktop:neovim.desktop :: Test (default)', result.stdout)
        self.assertIn('command:gui:code :: Visual Studio Code', result.stdout)
        self.assertNotIn('command:terminal:nvim', result.stdout)
        result = subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _fallback_app_options image/png', str(SOURCE)],
            env=self.env, capture_output=True, text=True)
        self.assertNotIn('command:gui:code', result.stdout)

    def test_terminal_fallback(self):
        result = self.run_option('command:terminal:editor')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('shell-alive', result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ['--', '/tmp/file with spaces.txt'])


if __name__ == '__main__':
    unittest.main()
