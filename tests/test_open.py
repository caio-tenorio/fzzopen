"""Exercise dispatch in disposable fish processes; never launch real GUI apps."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'functions' / 'fzzo.fish'


class OpenTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.apps = self.root / 'applications'
        self.apps.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.config_home = self.root / 'config'
        self.config_home.mkdir()
        self.log = self.root / 'args'
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root),
                        XDG_DATA_DIRS=str(self.root),
                        XDG_CONFIG_HOME=str(self.config_home),
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

    def config(self, body):
        config_dir = self.config_home / 'fzzopen'
        config_dir.mkdir(exist_ok=True)
        (config_dir / 'config.toml').write_text(body)

    def wait_for_log(self, timeout=2.0):
        # nohup+disown launches detach immediately; give the grandchild a moment to write.
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.log.exists():
                return self.log.read_text()
            time.sleep(0.02)
        self.fail(f'{self.log} was never written')

    def resolved_options(self, mime_type):
        result = subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _fzzo_resolved_app_options "$argv[2]"', str(SOURCE), mime_type],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def run_option(self, option, keep_shell=''):
        return subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _open_file_with_option "$argv[2]" "$argv[3]" "$argv[4]"; '
            'set result $status; echo shell-alive; exit $result',
            str(SOURCE), option, '/tmp/file with spaces.txt', keep_shell],
            env=self.env, capture_output=True, text=True)

    def test_autoload_changes_directory_in_current_shell(self):
        target = self.root / 'selected directory'
        target.mkdir()
        self.env['SELECTED_DIRECTORY'] = str(target)
        self.stub('fzf', 'cat > /dev/null\n'
                  'case "$1" in\n'
                  '  --read0) printf "%s\\n" "$SELECTED_DIRECTORY" ;;\n'
                  '  *) printf "cd :: Open in terminal\\n" ;;\n'
                  'esac')
        result = subprocess.run(['fish', '--no-config', '-c',
            'set -p fish_function_path "$argv[1]"; fzzo -k; pwd',
            str(SOURCE.parent)], cwd=self.root, env=self.env,
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(target))

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

    def test_keep_shell_flag_prevents_exit_on_gui_app(self):
        result = self.run_option('desktop:gui.desktop', keep_shell='true')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('shell-alive', result.stdout)
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
            'source "$argv[1]"; _fzzo_app_options text/plain', str(SOURCE)],
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

    def test_exclude_rule_scoped_to_mime_type(self):
        self.stub('vim', 'exit 0')
        self.config('''
[[exclude]]
mime = "inode/directory"
app = "vim"
''')
        directory_result = self.resolved_options('inode/directory')
        text_result = self.resolved_options('text/plain')
        self.assertNotIn('command:terminal:vim', directory_result.stdout)
        self.assertIn('command:terminal:vim', text_result.stdout)

    def test_exclude_rule_wildcard_all_mime_types(self):
        self.stub('vim', 'exit 0')
        self.config('''
[[exclude]]
mime = "*"
app = "vim"
''')
        result = self.resolved_options('text/plain')
        self.assertNotIn('command:terminal:vim', result.stdout)

    def test_include_rule_adds_and_launches_custom_app(self):
        self.stub('mytool', 'printf "%s\\n" "$@" > "$OPEN_LOG"')
        self.config('''
[[include]]
mime = "*"
label = "My Tool"
command = "mytool"
args = ["--flag", "with space"]
terminal = false
''')
        result = self.resolved_options('text/plain')
        self.assertIn('config:1 :: My Tool', result.stdout)

        launch = self.run_option('config:1')
        self.assertEqual(launch.returncode, 0, launch.stderr)
        self.assertNotIn('shell-alive', launch.stdout)
        self.assertEqual(self.wait_for_log().splitlines(),
                         ['--flag', 'with space', '--', '/tmp/file with spaces.txt'])

    def test_keep_shell_flag_prevents_exit_on_custom_gui_app(self):
        self.stub('mytool', 'printf "%s\\n" "$@" > "$OPEN_LOG"')
        self.config('''
[[include]]
mime = "*"
label = "My Tool"
command = "mytool"
terminal = false
''')
        launch = self.run_option('config:1', keep_shell='true')
        self.assertEqual(launch.returncode, 0, launch.stderr)
        self.assertIn('shell-alive', launch.stdout)
        self.assertEqual(self.wait_for_log().splitlines(),
                         ['--', '/tmp/file with spaces.txt'])

    def test_include_rule_terminal_app_preserves_shell(self):
        self.stub('mytool', 'printf "%s\\n" "$@" > "$OPEN_LOG"')
        self.config('''
[[include]]
mime = "*"
label = "My Terminal Tool"
command = "mytool"
terminal = true
''')
        launch = self.run_option('config:1')
        self.assertEqual(launch.returncode, 0, launch.stderr)
        self.assertIn('shell-alive', launch.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ['--', '/tmp/file with spaces.txt'])

    def test_include_rule_overrides_existing_catalog_entry(self):
        self.stub('code', 'exit 0')
        self.config('''
[[include]]
mime = "text/*"
label = "My VSCode"
command = "code"
''')
        result = self.resolved_options('text/plain')
        self.assertIn('config:1 :: My VSCode', result.stdout)
        self.assertNotIn('command:gui:code', result.stdout)
        self.assertNotIn('Visual Studio Code', result.stdout)

    def test_default_option_unaffected_by_excludes(self):
        self.stub('xdg-open', 'exit 0')
        self.config('''
[[exclude]]
mime = "*"
app = "xdg-open"
''')
        result = subprocess.run(['fish', '--no-config', '-c',
            'source "$argv[1]"; _default_app_option', str(SOURCE)],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('System default application', result.stdout)

    def test_malformed_config_warns_and_continues(self):
        self.stub('mytool', 'exit 0')
        self.config('''
this line is not valid
[[include]]
mime = "*"
label = "My Tool"
command = "mytool"
''')
        result = self.resolved_options('text/plain')
        self.assertIn('Warning: fzzopen config', result.stderr)
        self.assertIn('config:1 :: My Tool', result.stdout)

    def test_directory_options_go_through_catalog_and_config(self):
        self.stub('nvim', 'exit 0')
        self.stub('mytool', 'exit 0')
        self.config('''
[[exclude]]
mime = "inode/directory"
app = "nvim"

[[include]]
mime = "inode/directory"
label = "My File Manager"
command = "mytool"
''')
        result = self.resolved_options('inode/directory')
        self.assertNotIn('command:terminal:nvim', result.stdout)
        self.assertIn('config:1 :: My File Manager', result.stdout)


if __name__ == '__main__':
    unittest.main()
