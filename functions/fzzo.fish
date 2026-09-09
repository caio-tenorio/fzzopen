function _choose_app_option --description 'Pick an option'
    set -l options $argv

    if test (count $options) -eq 0
        echo "The functions must receive options" >&2
        return 1
    end

    if type -q fzf
        set -l sel (printf "%s\n" $options \
            | fzf --prompt="Open with: " --height=40% --reverse \
                  --delimiter=' :: ' --with-nth=2.. \
            | awk -F' :: ' '{print $1}')
        echo $sel
        return
    end

    echo "Choose the best option:"
    for i in (seq (count $options))
        set -l label (echo $options[$i] | awk -F' :: ' '{print $2}')
        echo "  $i) $label"
    end
    read -P "Number [1-"(count $options)"]: " idx
    if test -n "$idx"; and test $idx -ge 1; and test $idx -le (count $options)
        echo (echo $options[$idx] | awk -F' :: ' '{print $1}')
    end
end

function _gio_app_options --description 'List desktop applications associated with a MIME type'
    set -l mime_type $argv[1]
    test -n "$mime_type"; or return 1

    # gio provides the associations, while gtk-launch opens a selected desktop ID.
    # Without both commands, the caller should use the internal fallback list.
    type -q gio; or return 1
    type -q gtk-launch; or return 1

    set -l output (env LC_ALL=C gio mime "$mime_type" 2>/dev/null)
    test $status -eq 0; or return 1

    set -l default_app
    set -l recommended
    set -l registered
    set -l section

    for line in $output
        set -l trimmed (string trim -- "$line")

        if string match -qr '^Default application.*: .+\.desktop$' -- "$trimmed"
            set default_app (string replace -r '^Default application.*: ' '' -- "$trimmed")
            continue
        end

        switch "$trimmed"
            case 'Recommended applications:'
                set section recommended
            case 'Registered applications:'
                set section registered
            case '*.desktop'
                switch "$section"
                    case recommended
                        contains -- "$trimmed" $recommended; or set -a recommended "$trimmed"
                    case registered
                        contains -- "$trimmed" $registered; or set -a registered "$trimmed"
                end
        end
    end

    set -l desktop_ids
    test -n "$default_app"; and set -a desktop_ids "$default_app"

    for desktop_id in $recommended $registered
        contains -- "$desktop_id" $desktop_ids; or set -a desktop_ids "$desktop_id"
    end

    for desktop_id in $desktop_ids
        set -l suffix ''
        if test "$desktop_id" = "$default_app"
            set suffix ' (default)'
        end
        set -l label "$desktop_id"
        set -l desktop_file (_fzzo_desktop_file "$desktop_id")
        if test -n "$desktop_file"
            set -l app_name (_fzzo_desktop_value "$desktop_file" Name)
            test -n "$app_name"; and set label "$app_name"
        end
        echo "desktop:$desktop_id :: $label$suffix"
    end
end

function _fallback_app_options --description 'List installed applications from a small built-in catalog'
    set -l mime_type $argv[1]
    test -n "$mime_type"; or return 1

    set -l mime_group
    if string match -q 'text/*' -- "$mime_type"; or contains -- "$mime_type" \
            application/json application/xml application/javascript application/yaml \
            application/x-yaml application/x-shellscript inode/x-empty
        set mime_group text
    else if string match -q 'image/*' -- "$mime_type"
        set mime_group image
    else if test "$mime_type" = application/pdf
        set mime_group pdf
    else if string match -q 'audio/*' -- "$mime_type"
        set mime_group audio
    else if string match -q 'video/*' -- "$mime_type"
        set mime_group video
    else if test "$mime_type" = inode/directory
        set mime_group directory
    else
        return 0
    end

    set -l catalog \
        'text|terminal|nvim|Neovim' \
        'text|terminal|vim|Vim' \
        'text|terminal|micro|Micro' \
        'text|terminal|hx|Helix' \
        'text|gui|code|Visual Studio Code' \
        'text|gui|codium|VSCodium' \
        'text|gui|gedit|GNOME Text Editor' \
        'text|gui|kate|Kate' \
        'image|gui|loupe|Loupe' \
        'image|gui|eog|Eye of GNOME' \
        'image|gui|imv|imv' \
        'image|gui|feh|feh' \
        'pdf|gui|okular|Okular' \
        'pdf|gui|evince|Evince' \
        'pdf|gui|zathura|Zathura' \
        'audio|gui|mpv|mpv' \
        'audio|gui|vlc|VLC' \
        'video|gui|mpv|mpv' \
        'video|gui|vlc|VLC' \
        'directory|terminal|nvim|Neovim' \
        'directory|terminal|vim|Vim' \
        'directory|gui|code|Visual Studio Code' \
        'directory|gui|nautilus|GTK File Manager'

    set -l added_commands
    for entry in $catalog
        set -l fields (string split '|' -- "$entry")
        set -l app_group $fields[1]
        set -l mode $fields[2]
        set -l app $fields[3]
        set -l label $fields[4]

        test "$app_group" = "$mime_group"; or continue
        command -q "$app"; or continue
        contains -- "$app" $added_commands; and continue

        set -a added_commands "$app"
        echo "command:$mode:$app :: $label"
    end
end

function _fzzo_desktop_exec_command --description 'Resolve the executable basename a desktop entry launches'
    set -l desktop_file $argv[1]
    set -l tokens
    _fzzo_desktop_value "$desktop_file" Exec | read --tokenize --array tokens
    test (count $tokens) -gt 0; or return 1
    # Common desktop entries use either an executable or env VAR=value executable.
    if test (path basename -- "$tokens[1]") = env
        set -e tokens[1]
        while test (count $tokens) -gt 0
            string match -qr '^[A-Za-z_][A-Za-z_0-9]*=' -- "$tokens[1]"; or break
            set -e tokens[1]
        end
    end
    test (count $tokens) -gt 0; or return 1
    path basename -- "$tokens[1]"
end

function _fzzo_app_options --description 'Merge MIME associations with installed catalog applications'
    set -l options (_gio_app_options "$argv[1]")
    set -l desktop_commands
    for option in $options
        set -l id (string split ' :: ' -- "$option")[1]
        set -l desktop_file (_fzzo_desktop_file (string replace 'desktop:' '' -- "$id"))
        test -n "$desktop_file"; or continue
        set -l command (_fzzo_desktop_exec_command "$desktop_file")
        test -n "$command"; or continue
        set -a desktop_commands "$command"
    end
    for option in (_fallback_app_options "$argv[1]")
        set -l id (string split ' :: ' -- "$option")[1]
        set -l app (string split : -- "$id")[3]
        contains -- "$app" $desktop_commands; and continue
        set -a options "$option"
    end
    printf '%s\n' $options
end

function _fzzo_parse_toml_string --description 'Parse a double-quoted TOML string value (no escapes)'
    set -l value $argv[1]
    string match -qr '^"[^"]*"$' -- "$value"; or return 1
    string sub --start=2 --end=-1 -- "$value"
end

function _fzzo_parse_toml_string_array --description 'Parse a single-line TOML array of double-quoted strings'
    set -l value (string trim -- "$argv[1]")
    string match -qr '^\[.*\]$' -- "$value"; or return 1
    set -l inner (string trim -- (string sub --start=2 --end=-1 -- "$value"))
    test -z "$inner"; and return 0
    set -l items
    for raw_item in (string split ',' -- "$inner")
        set -l item (string trim -- "$raw_item")
        set -l parsed (_fzzo_parse_toml_string "$item")
        test $status -eq 0; or return 1
        set -a items "$parsed"
    end
    printf '%s\n' $items
end

function _fzzo_mime_matches --description 'Check a MIME pattern (exact, prefix/*, or *) against a MIME type'
    string match -q -- $argv[1] $argv[2]
end

function _fzzo_commit_config_rule --description 'Validate and store one parsed [[include]]/[[exclude]] rule'
    set -l section $argv[1]
    set -l line $argv[2]
    set -l app $argv[3]
    set -l label $argv[4]
    set -l command $argv[5]
    set -l terminal $argv[6]
    set -l mime $_fzzo_cfg_pending_mime
    set -l args $_fzzo_cfg_pending_args

    test -z "$section"; and return
    if test (count $mime) -eq 0
        echo "Warning: fzzopen config: $_fzzo_cfg_path:$line: [[$section]] is missing a valid 'mime'" >&2
        return
    end

    switch "$section"
        case exclude
            if test -z "$app"
                echo "Warning: fzzopen config: $_fzzo_cfg_path:$line: [[exclude]] is missing 'app'" >&2
                return
            end
            for pattern in $mime
                set -a _fzzo_cfg_exclude_mime "$pattern"
                set -a _fzzo_cfg_exclude_app "$app"
            end
        case include
            if test -z "$label" -o -z "$command"
                echo "Warning: fzzopen config: $_fzzo_cfg_path:$line: [[include]] requires 'label' and 'command'" >&2
                return
            end
            for pattern in $mime
                set -a _fzzo_cfg_include_mime "$pattern"
                set -a _fzzo_cfg_include_label "$label"
                set -a _fzzo_cfg_include_command "$command"
                set -a _fzzo_cfg_include_terminal "$terminal"
                set -l idx (count $_fzzo_cfg_include_mime)
                set -l varname "_fzzo_cfg_include_args_$idx"
                set -g $varname $args
            end
    end
end

function _fzzo_load_config --description 'Load ~/.config/fzzopen/config.toml include/exclude rules, once per process'
    set -q _fzzo_cfg_loaded; and return
    set -g _fzzo_cfg_loaded 1
    set -g _fzzo_cfg_exclude_mime
    set -g _fzzo_cfg_exclude_app
    set -g _fzzo_cfg_include_mime
    set -g _fzzo_cfg_include_label
    set -g _fzzo_cfg_include_command
    set -g _fzzo_cfg_include_terminal

    set -l config_home "$HOME/.config"
    set -q XDG_CONFIG_HOME; and set config_home "$XDG_CONFIG_HOME"
    set -g _fzzo_cfg_path "$config_home/fzzopen/config.toml"
    test -f "$_fzzo_cfg_path"; or return

    set -l section ''
    set -l section_line 0
    set -l cur_app ''
    set -l cur_label ''
    set -l cur_command ''
    set -l cur_terminal false
    set -g _fzzo_cfg_pending_mime
    set -g _fzzo_cfg_pending_args
    set -l line_no 0

    while read -l raw_line
        set line_no (math $line_no + 1)
        set -l line (string trim -- "$raw_line")
        test -z "$line"; and continue
        string match -q '#*' -- "$line"; and continue

        if string match -qr '^\[\[(include|exclude)\]\]$' -- "$line"
            _fzzo_commit_config_rule "$section" $section_line "$cur_app" "$cur_label" "$cur_command" "$cur_terminal"
            set section (string replace -r '^\[\[(.*)\]\]$' '$1' -- "$line")
            set section_line $line_no
            set cur_app ''
            set cur_label ''
            set cur_command ''
            set cur_terminal false
            set -g _fzzo_cfg_pending_mime
            set -g _fzzo_cfg_pending_args
            continue
        end

        if test -z "$section"
            echo "Warning: fzzopen config: $_fzzo_cfg_path:$line_no: line outside of [[include]]/[[exclude]]: $line" >&2
            continue
        end

        if not string match -qr '^[A-Za-z_]+\s*=\s*.+$' -- "$line"
            echo "Warning: fzzopen config: $_fzzo_cfg_path:$line_no: malformed line: $line" >&2
            continue
        end

        set -l key (string replace -r '^([A-Za-z_]+)\s*=.*$' '$1' -- "$line")
        set -l raw_value (string trim -- (string replace -r '^[A-Za-z_]+\s*=\s*' '' -- "$line"))

        switch "$key"
            case mime
                if string match -qr '^\[.*\]$' -- "$raw_value"
                    set -g _fzzo_cfg_pending_mime (_fzzo_parse_toml_string_array "$raw_value")
                else
                    set -g _fzzo_cfg_pending_mime (_fzzo_parse_toml_string "$raw_value")
                end
                if test (count $_fzzo_cfg_pending_mime) -eq 0
                    echo "Warning: fzzopen config: $_fzzo_cfg_path:$line_no: invalid mime value: $raw_value" >&2
                end
            case app
                set cur_app (_fzzo_parse_toml_string "$raw_value")
            case label
                set cur_label (_fzzo_parse_toml_string "$raw_value")
            case command
                set cur_command (_fzzo_parse_toml_string "$raw_value")
            case terminal
                if contains -- "$raw_value" true false
                    set cur_terminal "$raw_value"
                else
                    echo "Warning: fzzopen config: $_fzzo_cfg_path:$line_no: terminal must be true or false: $raw_value" >&2
                end
            case args
                set -g _fzzo_cfg_pending_args (_fzzo_parse_toml_string_array "$raw_value")
            case '*'
                echo "Warning: fzzopen config: $_fzzo_cfg_path:$line_no: unknown key '$key'" >&2
        end
    end < "$_fzzo_cfg_path"

    _fzzo_commit_config_rule "$section" $section_line "$cur_app" "$cur_label" "$cur_command" "$cur_terminal"
    set -e _fzzo_cfg_pending_mime
    set -e _fzzo_cfg_pending_args
end

function _fzzo_option_app_name --description 'Resolve the identity (executable basename) of an app option, or empty if unknown'
    set -l id (string split ' :: ' -- "$argv[1]")[1]
    set -l name ''
    switch "$id"
        case 'desktop:*'
            set -l desktop_file (_fzzo_desktop_file (string replace 'desktop:' '' -- "$id"))
            test -n "$desktop_file"; and set name (_fzzo_desktop_exec_command "$desktop_file")
        case 'command:*'
            set -l parts (string split ':' -- "$id")
            set name $parts[-1]
        case 'config:*'
            set -l idx (string replace 'config:' '' -- "$id")
            set name $_fzzo_cfg_include_command[$idx]
    end
    echo "$name"
end

function _fzzo_resolved_app_options --description 'Apply user config include/exclude rules on top of system and catalog options for a MIME type'
    set -l mime $argv[1]
    _fzzo_load_config
    set -l options (_fzzo_app_options "$mime")
    set -l identities
    for option in $options
        set -a identities (_fzzo_option_app_name "$option")
    end

    for i in (seq (count $_fzzo_cfg_include_mime))
        _fzzo_mime_matches "$_fzzo_cfg_include_mime[$i]" "$mime"; or continue
        set -l command $_fzzo_cfg_include_command[$i]
        command -q "$command"; or continue
        set -l label $_fzzo_cfg_include_label[$i]
        set -l replaced 0
        for j in (seq (count $identities))
            if test "$identities[$j]" = "$command"
                set options[$j] "config:$i :: $label"
                set replaced 1
                break
            end
        end
        if test $replaced -eq 0
            set -a options "config:$i :: $label"
            set -a identities "$command"
        end
    end

    set -l kept
    for k in (seq (count $options))
        set -l excluded 0
        for i in (seq (count $_fzzo_cfg_exclude_mime))
            _fzzo_mime_matches "$_fzzo_cfg_exclude_mime[$i]" "$mime"; or continue
            if test "$identities[$k]" = "$_fzzo_cfg_exclude_app[$i]"
                set excluded 1
                break
            end
        end
        test $excluded -eq 1; or set -a kept $options[$k]
    end
    printf '%s\n' $kept
end

function _default_app_option --description 'Print the system-default opener option when available'
    if type -q xdg-open
        echo 'default:xdg-open :: System default application'
    else if type -q gio
        echo 'default:gio :: System default application'
    end
end

function _fzzo_desktop_file --description 'Resolve a desktop ID in XDG precedence order'
    set -l data_home "$HOME/.local/share"
    set -q XDG_DATA_HOME; and set data_home "$XDG_DATA_HOME"
    set -l data_dirs /usr/local/share /usr/share
    set -q XDG_DATA_DIRS; and set data_dirs (string split : -- "$XDG_DATA_DIRS")
    for root in "$data_home" $data_dirs
        set -l applications "$root/applications"
        if test -f "$applications/$argv[1]"
            echo "$applications/$argv[1]"
            return 0
        end
        test -d "$applications"; or continue
        for entry in (find "$applications" -name '*.desktop' -type f -print0 | string split0)
            set -l relative (string sub --start (math (string length -- "$applications") + 2) -- "$entry")
            if test (string replace -a / - -- "$relative") = "$argv[1]"
                echo "$entry"
                return 0
            end
        end
    end
    return 1
end

function _fzzo_desktop_value --description 'Read a key from the main Desktop Entry group'
    command awk -v key="$argv[2]" '
        /^\[/ { main = ($0 == "[Desktop Entry]") }
        main && index($0, key "=") == 1 {
            print substr($0, length(key) + 2); exit
        }
    ' "$argv[1]"
end

function _fzzo_terminal_desktop --description 'Run a terminal desktop entry in this terminal'
    set -l desktop_file "$argv[1]"
    set -l file "$argv[2]"
    set -l tokens
    _fzzo_desktop_value "$desktop_file" Exec | read --tokenize --array tokens
    test (count $tokens) -gt 0; or return 1
    set -l args
    for token in $tokens
        switch "$token"
            case '%f' '%F' '%u' '%U'
                set -a args "$file"
            case '%i'
                set -l icon (_fzzo_desktop_value "$desktop_file" Icon)
                test -n "$icon"; and set -a args --icon "$icon"
            case '%c'
                set -a args (_fzzo_desktop_value "$desktop_file" Name)
            case '%k'
                set -a args "$desktop_file"
            case '%d' '%D' '%n' '%N' '%v' '%m'
                # Deprecated field codes are omitted.
            case '*'
                set -a args (string replace -a '%%' '%' -- "$token")
        end
    end
    test (count $args) -gt 0; or return 1
    set -l previous_directory "$PWD"
    set -l working_directory (_fzzo_desktop_value "$desktop_file" Path)
    if test -n "$working_directory"
        cd "$working_directory"; or return 1
    end
    command $args
    set -l result $status
    if test -n "$working_directory"
        cd "$previous_directory"
    end
    return $result
end

function _open_file_with_option --description 'Open a file using an option returned by the application picker'
    set -l option $argv[1]
    set -l file $argv[2]
    set -l keep_shell $argv[3]

    switch "$option"
        case 'desktop:*'
            set -l desktop_id (string replace 'desktop:' '' -- "$option")
            set -l desktop_file (_fzzo_desktop_file "$desktop_id")
            if test -z "$desktop_file"
                echo "Desktop entry not found: $desktop_id" >&2
                return 1
            end
            set -l terminal (_fzzo_desktop_value "$desktop_file" Terminal)
            if test "$terminal" = true
                _fzzo_terminal_desktop "$desktop_file" "$file"
                return $status
            end
            # Keep launch errors visible and only close the shell on success.
            if type -q gtk-launch
                gtk-launch "$desktop_id" "$file"; or return $status
            else
                gio launch "$desktop_file" "$file"; or return $status
            end
            if test "$keep_shell" != true
                exit 0
            end
        case 'command:terminal:*'
            set -l app (string replace 'command:terminal:' '' -- "$option")
            command "$app" -- "$file"
        case 'command:gui:*'
            set -l app (string replace 'command:gui:' '' -- "$option")
            nohup "$app" -- "$file" >/dev/null 2>&1 &
            disown
            if test "$keep_shell" != true
                exit 0
            end
        case 'config:*'
            _fzzo_load_config
            set -l idx (string replace 'config:' '' -- "$option")
            set -l app $_fzzo_cfg_include_command[$idx]
            set -l argname "_fzzo_cfg_include_args_$idx"
            set -l extra_args $$argname
            if test "$_fzzo_cfg_include_terminal[$idx]" = true
                command "$app" $extra_args -- "$file"
            else
                nohup "$app" $extra_args -- "$file" >/dev/null 2>&1 &
                disown
                if test "$keep_shell" != true
                    exit 0
                end
            end
        case 'default:*'
            # Resolve the default desktop entry too, so terminal defaults stay here.
            set -l mime_type (command file --brief --mime-type -- "$file")
            set -l desktop_id
            if type -q gio
                set desktop_id (env LC_ALL=C gio mime "$mime_type" 2>/dev/null | string match -r '^Default application.*: (.+)$' | tail -n 1)
            else if type -q xdg-mime
                set desktop_id (xdg-mime query default "$mime_type")
            end
            if test -n "$desktop_id"
                _open_file_with_option "desktop:$desktop_id" "$file" "$keep_shell"
                return $status
            end
            echo "Could not identify the default application for $mime_type." >&2
            return 1
        case '*'
            return 1
    end
end

function fzzo
    set -l base_cmd ''
    set -l hidden_cmd ''

    if type -q fd
        set base_cmd "fd -t f -t d --strip-cwd-prefix --color=never \
                         --exclude node_modules --exclude .vscode --exclude .idea \
                         --exclude dist --exclude build --exclude target --exclude .cache -0"
        # with hidden (keeps some junk filtered out)
        set hidden_cmd "fd -t f -t d --strip-cwd-prefix --color=never --hidden --follow \
                         --exclude .git --exclude node_modules --exclude .vscode --exclude .idea \
                         --exclude dist --exclude build --exclude target --exclude .cache -0"
    else
        # without hidden
        set base_cmd "find . \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.vscode' -o -path '*/.idea' -o -path '*/dist' -o -path '*/build' -o -path '*/target' -o -path '*/.cache' -o -path '*/.*' \) -prune -o -type f -print0 -o -type d -print0"
        # with hidden (only filters large junk)
        set hidden_cmd "find . \( -path '*/.git' -o -path '*/node_modules' -o -path '*/.vscode' -o -path '*/.idea' -o -path '*/dist' -o -path '*/build' -o -path '*/target' -o -path '*/.cache' \) -prune -o -type f -print0 -o -type d -print0"
    end

    # allows opening with hidden files right away: `fzzo -h` or `fzzo --hidden`
    # `fzzo -k` / `fzzo --stay` keeps this shell open after launching a GUI app
    set -l start_cmd $base_cmd
    set -l header 'Hidden: OFF  (Alt-h on / Alt-H off)'
    set -l keep_shell false
    for arg in $argv
        switch "$arg"
            case -h --hidden
                set start_cmd $hidden_cmd
                set header 'Hidden: ON   (Alt-h on / Alt-H off)'
            case -k --stay
                set keep_shell true
        end
    end

    set -l file (eval $start_cmd \
        | fzf --read0 --height=90% --border \
              --header "$header" \
              --preview 'test -d {} && { ls -A {} | head -n 50; } || { file --mime-type -b {} | grep -qiF -e 'text' -e 'json' -e 'javascript' && bat --style=numbers --color=always --paging=never {} || file --brief {}; }' \
              --bind "alt-h:reload($hidden_cmd)+change-header(Hidden: ON   (Alt-h on / Alt-H off))" \
              --bind "alt-H:reload($base_cmd)+change-header(Hidden: OFF  (Alt-h on / Alt-H off))")
    test -z "$file"; and return

    if test -d "$file"
        set -l dir_to_open "$file"
        if not string match -q '/*' -- "$dir_to_open"
            set dir_to_open "$PWD/$dir_to_open"
        end

        set -l directory_options 'cd :: Open in terminal'
        set -a directory_options (_fzzo_resolved_app_options inode/directory)
        set -a directory_options (_default_app_option)

        set -l selected (_choose_app_option $directory_options)
        if test "$selected" = cd -o -z "$selected"
            # Cancelling (or explicitly choosing "cd") defaults to just changing directory.
            cd "$file"
            return
        end
        _open_file_with_option "$selected" "$dir_to_open" "$keep_shell"
        return
    end

    set -l mime_type (file --brief --mime-type -- "$file")

    set -l app_options (_fzzo_resolved_app_options "$mime_type")

    set -a app_options (_default_app_option)

    if test (count $app_options) -eq 0
        echo "No application available for $mime_type." >&2
        return 1
    end

    set -l selected (_choose_app_option $app_options)
    if test -z "$selected"
        echo 'Canceled.'
        return 0
    end

    set -l file_to_open "$file"
    if not string match -q '/*' -- "$file_to_open"
        set file_to_open "$PWD/$file_to_open"
    end

    _open_file_with_option "$selected" "$file_to_open" "$keep_shell"
end
