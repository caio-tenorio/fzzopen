function _choose_app_option --description 'Pick an option'
    set -l options $argv
    
    if test (count $options) -eq 0
        echo "The functions must receive options" >&2
        return 1
    end

    if type -q fzf
        set -l sel (printf "%s\n" $options \
            | fzf --prompt="Abrir com: " --height=40% --reverse \
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
        set -l editor (_choose_app_option \
                            "cd :: Abrir no terminal" \
                            "code :: Visual Studio Code" \
                            "nautilus :: GTK File Manager")
        switch $editor
            case cd
                cd "$file"
            case code
                nohup code "$file" >/dev/null 2>&1 &
                disown
                exit
            case nautilus
                nohup nautilus "$file" >/dev/null 2>&1 &
                disown
                exit
            case '*'
                # fallback
                cd "$file"
        end
        return
    end

    set -l mime_type (file --brief --mime-type -- "$file")

    if string match -q 'text/*' -- $mime_type; \
    or string match -q 'application/json' -- $mime_type; \
    or string match -q 'application/xml' -- $mime_type; \
    or string match -q 'application/javascript' -- $mime_type; \
    or string match -q 'application/x-yaml' -- $mime_type; \
    or string match -q 'application/x-shellscript' -- $mime_type; \
    or string match -q 'inode/x-empty' -- $mime_type
        
        set -l editor (_choose_app_option \
                        "nvim :: Abrir no terminal" \
                        "code :: Visual Studio Code" \
                        "gedit :: Editor simples (GTK)" \
                        "kate :: Editor KDE")
        if test -z "$editor"
            echo "Cancelled."
            exit 0
        end

        switch $editor
            case nvim
                nvim -- "$file"
            case code
                nohup code --reuse-window -- "$file" >/dev/null 2>&1 &
                disown
                exit
            case gedit
                nohup gedit -- "$file" >/dev/null 2>&1 &
                disown
                exit
            case kate
                nohup kate -- "$file" >/dev/null 2>&1 &
                disown
                exit
            case '*'
                vim -- "$file"
        end

    else if string match -q 'image/*' -- $mime_type
        nohup loupe -- "$file" >/dev/null 2>&1 &
        disown
        exit

    else if string match -q 'application/pdf' -- $mime_type
        nohup okular -- "$file" >/dev/null 2>&1 &
        disown
        exit

    else
        # fallback
        nohup xdg-open -- "$file" >/dev/null 2>&1 &
        disown
        exit
    end
end
