---
name: windows-telemetry-off
description: Disable Windows and Microsoft Edge telemetry/diagnostic upload paths — DiagTrack service, Diagtrack-Listener ETW autologger, telemetry scheduled tasks, diagnostic-data policies, activity feed, content delivery, input personalization, and Edge diagnostic policies. Keeps security features (Defender cloud protection, SmartScreen, sample submission) intact. Use when the user wants to harden Windows privacy or shut off Microsoft data collection.
---

# windows-telemetry-off

One-shot hardening for Windows 11 telemetry. Single idempotent script — safe to re-run.

## Usage

Run on the Windows host (or via `powershell.exe` from WSL). Self-elevates through UAC if not admin; **elevate as the same user** so HKCU lands in the right hive.

```powershell
powershell -ExecutionPolicy Bypass -File apply.ps1
```

Log: `%TEMP%\windows-telemetry-off.log`. Reboot once — the live `Diagtrack-Listener` ETW session is kernel-protected and only stops at boot (`Start=0` already prevents re-arm).

## What it disables

| Layer | Items |
|---|---|
| Services | `DiagTrack` (telemetry pipeline), `dmwappushservice` |
| ETW | `Diagtrack-Listener` autologger `Start=0` |
| Scheduled tasks | CEIP ×3, Compatibility Appraiser/DataUpdater, PCA, StartupApp, Autochk Proxy, Siuf feedback ×2, WER queue, disk/sustainability diagnostics, FamilySafety ×2, Maps toast |
| HKLM policies | AllowTelemetry=0 + log/dump limits, AppCompat telemetry, CEIP, consumer content, activity feed (record/publish/upload), search suggestions, WER, advertising ID, input personalization, handwriting reports, app diagnostic access |
| HKCU | ContentDeliveryManager (22 values), input/inking collection, feedback prompts, Cortana/search box, tailored experiences, ad ID, app launch tracking, language-list opt-out |
| Edge | 13 policies — diagnostic data, usage/crash reporting, history personalization, feedback, search suggestions, error reporting, experiments, promos/recommendations |
| Local store | Deletes `ActivitiesCache.db` (stops `CDPUserSvc_*` first) |

## Deliberately kept

- Defender: cloud protection (MAPS) + automatic sample submission — real security
- SmartScreen, Edge startup boost, location services, Timeline-adjacent local features

## Revert

Everything is standard policy keys / tasks / services — delete the values under `HKLM/HKCU\SOFTWARE\Policies\...` and re-enable items to undo.

## Pitfall

`New-Item -Force` on an **existing** registry key deletes and recreates it, wiping sibling values. The script uses `Test-Path` instead — don't "simplify" this back.
