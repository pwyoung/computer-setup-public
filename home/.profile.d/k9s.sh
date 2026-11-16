
k9s ()
{
    if [[ -n "${ZELLIJ:-}" ]]; then
        local rc;
        zellij action rename-tab "k9s";
        zellij action rename-pane "k9s";
        command k9s "$@";
        rc=$?;
        zellij action undo-rename-pane;
        zellij action undo-rename-tab;
        return $rc;
    fi;
    command k9s "$@";
}
