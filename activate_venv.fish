#!/usr/bin/env fish
# Activate Python virtual environment for Fish shell

if test -d .venv
    # Add venv to PATH
    set -gx PATH .venv/bin $PATH
    set -gx VIRTUAL_ENV (pwd)/.venv

    # Update the prompt
    functions -c fish_prompt _old_fish_prompt
    function fish_prompt
        echo -n "(venv) "
        _old_fish_prompt
    end

    echo "Python virtual environment activated"
    echo "  Ansible: "(which ansible)
    echo "  Python: "(which python)
else
    echo "No virtual environment found. Run 'python -m venv .venv' first."
end
