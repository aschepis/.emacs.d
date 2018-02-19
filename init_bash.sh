{
    function emacs_eval() {
        emacsclient --eval "(with-current-buffer (window-buffer) $@)"
    }
    function emacs_project_name() {
        emacs_eval '(projectile-project-name)'
    }
    function emacs_project_root() {
        emacs_eval '(projectile-project-root)'
    }
    function gen_prompt() {
        # This resets the project name
        emacs_eval '(rename-buffer-with-project)' &> /dev/null
        project=$(emacs_project_name | tr -d '"\n')
        if [[ "$project" = '-' ]]; then
            PS1="\h:\W$ "
        else
            # Manually reset project root
            emacs_eval '(projectile-reset-cached-project-root)' &> /dev/null
            root=$(emacs_project_root | tr -d '"\n')
            if [[ "$PWD/" = "$root" ]]; then
                PS1="[$project]$ "
            else
                PS1="[$project]\W$ "
            fi
        fi
    }
    PROMPT_COMMAND="gen_prompt"
} &> /dev/null
echo
