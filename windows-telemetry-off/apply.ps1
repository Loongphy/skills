# windows-telemetry-off — disable Windows/Edge telemetry upload paths.
# Run as the target user. Self-elevates via UAC if not admin.
# Safe to re-run (idempotent). See SKILL.md for the full item list.

$ErrorActionPreference = 'Continue'
$log = [System.Collections.Generic.List[string]]::new()
function note($m) { $log.Add($m); Write-Host $m }

# Self-elevate (same account, so HKCU still targets the right hive)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    note 'Not elevated — relaunching with UAC...'
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    exit
}

function Set-Values($path, [hashtable]$values) {
    # NOTE: do NOT use New-Item -Force on an existing key — it deletes and
    # recreates the key, wiping sibling values. Test-Path first.
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        foreach ($k in $values.Keys) {
            Set-ItemProperty -Path $path -Name $k -Value $values[$k] -Force
            note "OK  $path\$k = $($values[$k])"
        }
    } catch { note "FAIL $path : $($_.Exception.Message)" }
}

note '=== Services ==='
foreach ($s in 'DiagTrack','dmwappushservice') {
    try {
        Stop-Service $s -Force -ErrorAction SilentlyContinue
        Set-Service $s -StartupType Disabled -ErrorAction Stop
        note "OK  service $s -> Disabled"
    } catch { note "FAIL service $s : $($_.Exception.Message)" }
}

note '=== Diagtrack-Listener autologger (takes effect at next boot; live session is protected) ==='
try {
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener' -Name Start -Value 0 -Type DWord -Force
    note 'OK  Autologger\Diagtrack-Listener Start=0'
} catch { note "FAIL autologger: $($_.Exception.Message)" }

note '=== Scheduled tasks ==='
$tasks = @(
  @('\Microsoft\Windows\Customer Experience Improvement Program\','Consolidator'),
  @('\Microsoft\Windows\Customer Experience Improvement Program\','UsbCeip'),
  @('\Microsoft\Windows\Customer Experience Improvement Program\','KernelCeipTask'),
  @('\Microsoft\Windows\Application Experience\','Microsoft Compatibility Appraiser'),
  @('\Microsoft\Windows\Application Experience\','ProgramDataUpdater'),
  @('\Microsoft\Windows\Application Experience\','PcaPatchDbTask'),
  @('\Microsoft\Windows\Application Experience\','StartupAppTask'),
  @('\Microsoft\Windows\Autochk\','Proxy'),
  @('\Microsoft\Windows\Feedback\Siuf\','DmClient'),
  @('\Microsoft\Windows\Feedback\Siuf\','DmClientOnScenarioDownload'),
  @('\Microsoft\Windows\Windows Error Reporting\','QueueReporting'),
  @('\Microsoft\Windows\DiskDiagnostic\','Microsoft-Windows-DiskDiagnosticDataCollector'),
  @('\Microsoft\Windows\PerformanceTrace\','ShowFeedbackToast'),
  @('\Microsoft\Windows\Sustainability\','SustainabilityTelemetry'),
  @('\Microsoft\Windows\Shell\','FamilySafetyMonitor'),
  @('\Microsoft\Windows\Shell\','FamilySafetyRefreshTask'),
  @('\Microsoft\Windows\Maps\','MapsToastTask')
)
foreach ($t in $tasks) {
    try {
        Disable-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction Stop | Out-Null
        note "OK  task $($t[0])$($t[1])"
    } catch { note "SKIP task $($t[1]) : $($_.Exception.Message)" }
}

note '=== HKLM policies ==='
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' @{
    AllowTelemetry = 0
    DoNotShowFeedbackNotifications = 1
    LimitDiagnosticLogCollection = 1
    LimitDumpCollection = 1
    DisableEnterpriseAuthProxy = 1
}
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' @{
    AITEnable = 0
    DisableInventory = 1
    DisableUAR = 1
}
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' @{ CEIPEnable = 0 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' @{
    DisableSoftLanding = 1
    DisableWindowsConsumerFeatures = 1
    DisableCloudOptimizedContent = 1
}
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' @{
    EnableActivityFeed = 0
    EnableAppUriHandlers = 0
    UploadUserActivities = 0
    PublishUserActivities = 0
}
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' @{ DisableSearchBoxSuggestions = 1 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' @{
    Disabled = 1
    DontSendAdditionalData = 1
}
Set-Values 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' @{ Disabled = 1 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' @{ DisabledByGroupPolicy = 1 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' @{ AllowInputPersonalization = 0 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports' @{ PreventHandwritingErrorReports = 1 }
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' @{ LetAppsGetDiagnosticInfo = 2 }

note '=== Edge policies (edge://policy after restart) ==='
Set-Values 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' @{
    DiagnosticData = 0
    MetricsReportingEnabled = 0
    PersonalizationReportingEnabled = 0
    UserFeedbackAllowed = 0
    EdgeImprove = 0
    SearchSuggestEnabled = 0
    ResolveNavigationErrorsUseWebService = 0
    AlternateErrorPagesEnabled = 0
    ExperimentationAndConfigurationServiceControl = 0
    ShowRecommendationsEnabled = 0
    SpotlightExperiencesAndRecommendationsEnabled = 0
    MicrosoftEdgeInsiderPromotionEnabled = 0
    PromotionalTabsEnabled = 0
}

note '=== HKCU policies ==='
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' @{
    SystemPaneSuggestionsEnabled = 0
    SoftLandingEnabled = 0
    'SubscribedContent-338388Enabled' = 0
    'SubscribedContent-338389Enabled' = 0
    'SubscribedContent-338393Enabled' = 0
    'SubscribedContent-353698Enabled' = 0
    'SubscribedContent-314563Enabled' = 0
    'SubscribedContent-310093Enabled' = 0
    'SubscribedContent-314559Enabled' = 0
    'SubscribedContent-280810Enabled' = 0
    'SubscribedContent-280811Enabled' = 0
    'SubscribedContent-280812Enabled' = 0
    'SubscribedContent-280815Enabled' = 0
    SilentInstalledAppsEnabled = 0
    PreInstalledAppsEnabled = 0
    PreInstalledAppsEverEnabled = 0
    OemPreInstalledAppsEnabled = 0
    ContentDeliveryAllowed = 0
    FeatureManagementEnabled = 0
    RemediationRequired = 0
    RotatingLockScreenEnabled = 0
    RotatingLockScreenOverlayEnabled = 0
}
Set-Values 'HKCU:\SOFTWARE\Microsoft\InputPersonalization' @{
    RestrictImplicitTextCollection = 1
    RestrictImplicitInkCollection = 1
}
Set-Values 'HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore' @{ HarvestContacts = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Personalization\Settings' @{ AcceptedPrivacyPolicy = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Input\TIPC' @{ Enabled = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' @{
    NumberOfSIUFInPeriod = 0
    PeriodInNanoSeconds = 0
}
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' @{
    CortanaConsent = 0
    IsAssignedAccess = 0
}
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' @{ IsDynamicSearchBoxEnabled = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' @{ TailoredExperiencesWithDiagnosticDataEnabled = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' @{ Enabled = 0 }
Set-Values 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' @{
    Start_TrackProgs = 0
    Start_TrackDocs = 0
}
Set-Values 'HKCU:\Control Panel\International\User Profile' @{ HttpAcceptLanguageOptOut = 1 }

note '=== Activity feed local store ==='
try {
    Get-Service 'CDPUserSvc_*' -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\ConnectedDevicesPlatform\*\ActivitiesCache.db*" -Force -ErrorAction SilentlyContinue
    note 'OK  ActivitiesCache.db removed (feed disabled, stays empty)'
} catch { note "FAIL activities cache: $($_.Exception.Message)" }

note "`nDone. Reboot to stop the live Diagtrack-Listener ETW session."
$log | Out-File "$env:TEMP\windows-telemetry-off.log" -Encoding utf8
