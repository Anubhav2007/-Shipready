<#
.SYNOPSIS
    Installs the shipready skill for your AI agents (Claude Code, Cursor, Windsurf, Cline, Copilot).
.DESCRIPTION
    Runs the Node-based installer to copy files to the correct agent directories.
.EXAMPLE
    .\install-skill.ps1
.EXAMPLE
    .\install-skill.ps1 --check
.EXAMPLE
    .\install-skill.ps1 --uninstall
#>

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
node "$ScriptPath\bin\install.js" $args
