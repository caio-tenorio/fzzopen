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
        set -l desktop_file (_fopen_desktop_file "$desktop_id")
        if test -n "$desktop_file"
            set -l app_name (_fopen_desktop_value "$desktop_file" Name)
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
        'video|gui|vlc|VLC'

    set -l added_commands
    for entry in $catalog
        set -l fields (string split '|' -- "$entry")
        set -l app_group $fields[1]
        set -l mode $fields[2]
        set -l app $fields[3]
        set -l label $fields[4]

        test "$app_group" = "$mime_group"; or continue
        type -q "$app"; or continue
        contains -- "$app" $added_commands; and continue

        set -a added_commands "$app"
        echo "command:$mode:$app :: $label"
    end
end

function _default_app_option --description 'Print the system-default opener option when available'
    if type -q xdg-open
        echo 'default:xdg-open :: System default application'
    else if type -q gio
        echo 'default:gio :: System default application'
    end
end

function _fopen_desktop_file --description 'Resolve a desktop ID in XDG precedence order'
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

function _fopen_desktop_value --description 'Read a key from the main Desktop Entry group'
    command awk -v key="$argv[2]" '
        /^\[/ { main = ($0 == "[Desktop Entry]") }
        main && index($0, key "=") == 1 {
            print substr($0, length(key) + 2); exit
        }
    ' "$argv[1]"
end

function _fopen_terminal_desktop --description 'Run a terminal desktop entry in this terminal'
    set -l desktop_file "$argv[1]"
    set -l file "$argv[2]"
    set -l tokens
    _fopen_desktop_value "$desktop_file" Exec | read --tokenize --array tokens
    test (count $tokens) -gt 0; or return 1
    set -l args
    for token in $tokens
        switch "$token"
            case '%f' '%F' '%u' '%U'
                set -a args "$file"
            case '%i'
                set -l icon (_fopen_desktop_value "$desktop_file" Icon)
                test -n "$icon"; and set -a args --icon "$icon"
            case '%c'
                set -a args (_fopen_desktop_value "$desktop_file" Name)
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
    set -l working_directory (_fopen_desktop_value "$desktop_file" Path)
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

    switch "$option"
        case 'desktop:*'
            set -l desktop_id (string replace 'desktop:' '' -- "$option")
            set -l desktop_file (_fopen_desktop_file "$desktop_id")
            if test -z "$desktop_file"
                echo "Desktop entry not found: $desktop_id" >&2
                return 1
            end
            set -l terminal (_fopen_desktop_value "$desktop_file" Terminal)
            if test "$terminal" = true
                _fopen_terminal_desktop "$desktop_file" "$file"
                return $status
            end
            # Keep launch errors visible and only close the shell on success.
            if type -q gtk-launch
                gtk-launch "$desktop_id" "$file"; or return $status
            else
                gio launch "$desktop_file" "$file"; or return $status
            end
            exit
        case 'command:terminal:*'
            set -l app (string replace 'command:terminal:' '' -- "$option")
            command "$app" -- "$file"
        case 'command:gui:*'
            set -l app (string replace 'command:gui:' '' -- "$option")
            nohup "$app" -- "$file" >/dev/null 2>&1 &
            disown
            exit
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
                _open_file_with_option "desktop:$desktop_id" "$file"
                return $status
            end
            echo "Could not identify the default application for $mime_type." >&2
            return 1
        case '*'
            return 1
    end
end

function fopen
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

    # allows opening with hidden files right away: `fopen -h` or `fopen --hidden`
    set -l start_cmd $base_cmd
    set -l header 'Hidden: OFF  (Alt-h on / Alt-H off)'
    if test (count $argv) -gt 0
        if test "$argv[1]" = -h -o "$argv[1]" = --hidden
            set start_cmd $hidden_cmd
            set header 'Hidden: ON   (Alt-h on / Alt-H off)'
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
        set -l directory_options 'cd :: Open in terminal'
        type -q code; and set -a directory_options 'code :: Visual Studio Code'
        type -q nautilus; and set -a directory_options 'nautilus :: GTK File Manager'

        set -l selected (_choose_app_option $directory_options)
        switch $selected
            case cd
                cd "$file"
            case code
                _open_file_with_option command:gui:code "$PWD/$file"
            case nautilus
                _open_file_with_option command:gui:nautilus "$PWD/$file"
            case '*'
                # fallback
                cd "$file"
        end
        return
    end

    set -l mime_type (file --brief --mime-type -- "$file")

    set -l app_options (_gio_app_options "$mime_type")
    if test (count $app_options) -eq 0
        set app_options (_fallback_app_options "$mime_type")
    end

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

    _open_file_with_option "$selected" "$file_to_open"
end
