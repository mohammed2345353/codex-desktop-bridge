#Requires -Version 5.1
# Short entry point. Named arguments and -WhatIf are forwarded unchanged.
& (Join-Path $PSScriptRoot 'scripts/Invoke-ToolAdvisor.ps1') @args
