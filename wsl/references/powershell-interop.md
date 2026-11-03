# PowerShell Interop Reference

## Restore the Windows PATH

`pwsh.exe -NoProfile` is predictable, but it does not run profile scripts that might repair missing per-user `PATH` entries. When a Windows-side tool is installed but cannot be found, rebuild `PATH` from the Windows registry before invoking it:

```powershell
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = @($machinePath, $userPath) -join ";"
```

If only one known directory is required, append that directory instead of rebuilding the entire value:

```powershell
$env:Path += ";$env:USERPROFILE\.cargo\bin"
```

## Protect PowerShell Variables from Bash

Bash parses a `pwsh.exe -Command` payload before PowerShell receives it. Wrap the complete payload in Bash single quotes when it contains `$name` or `$env:NAME`, and use PowerShell double quotes inside the payload as needed:

```bash
pwsh.exe -NoLogo -NoProfile -Command '$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine"); $userPath = [Environment]::GetEnvironmentVariable("Path", "User"); $env:Path = @($machinePath, $userPath) -join ";"; cargo --version'
```

Do not wrap that payload in Bash double quotes unless Bash expansion is intentional.

This is incorrect because Bash expands `$env` before PowerShell starts:

```bash
pwsh.exe -NoProfile -Command "Write-Host ('VSINSTALL=' + $env:VSINSTALLDIR)"
```

PowerShell then receives text resembling `:VSINSTALLDIR`, which commonly produces a parser error such as `You must provide a value expression following the '+' operator`.

Use a Bash single-quoted payload instead. For example, initialize a Visual Studio Developer PowerShell environment from WSL with:

```bash
pwsh.exe -NoProfile -Command 'Import-Module "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"; Enter-VsDevShell 4c595161 -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64"; Write-Host ("VSINSTALL=" + $env:VSINSTALLDIR); dotnet --version'
```

Before running a payload containing PowerShell variables, check the Bash quoting boundary:

- The character immediately after `-Command` should normally be a Bash single quote.
- PowerShell variables such as `$env:VSINSTALLDIR` must remain literal in the command Bash passes onward.
- Prefer PowerShell double-quoted strings inside the outer Bash single quotes.

For a long payload with both Bash and PowerShell quoting requirements, use PowerShell's UTF-16LE `-EncodedCommand` or place a `.ps1` file on the Windows filesystem. This avoids maintaining multiple nested escaping layers.

## Initialize Another Windows Environment Variable

Read registry-backed variables explicitly when a Windows command launched from WSL needs them:

```powershell
$env:FOO = [Environment]::GetEnvironmentVariable("FOO", "User")
```

Use PowerShell double quotes when the assigned string must expand variables such as `$env:USERPROFILE`; use single quotes for literal strings.
