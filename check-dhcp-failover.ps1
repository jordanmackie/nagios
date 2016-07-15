$exitcode = 0

# Enssure Script Runs Only On Windows Server 2012 Hosts
if (!($((Get-WmiObject -class Win32_OperatingSystem).Caption) -like "*Windows Server 2012*")){
    Write-Host "Error: Host not running Windows Server 2012"
}

# Ensure Required Cmdlets Are Available
$RequiredCmdlets = @(
    "Get-DhcpServerv4Failover",
    "Get-DhcpServerv4Scope",
    "Get-DhcpServerv4ScopeStatistics"
)
$ExitCodeInc = 1
ForEach ( $Cmdlet in $RequiredCmdlets ) {
    $CmdletExitCodeVar = "CmdletExitCode" + $ExitCodeInc
    Get-Command $Cmdlet 2>&1 | Out-Null
    if ( $? -ne "True" ) {
        Write-Host "ERROR: Missing Cmdlet -"$Cmdlet
        $CmdletExitCode = 2
    }
    if (( $CmdletExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $CmdletExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $CmdletExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }
    $ExitCodeInc++
}

# Exit If Sanity Failed
if ( $exitcode -ne 0 ) { exit $exitcode }

# ----------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------

$DesiredFailoverMode = "HotStandby"
$DesiredFailoverState = "Normal"
$DesiredScopeState = "Active"
$ScopePercentInUse_LowWarning = "-1"
$ScopePercentInUse_LowCritical = "-1"
$ScopePercentInUse_HighWarning = "90"
$ScopePercentInUse_HighCritical = "95"

$FailoverOutput = Get-DhcpServerv4Failover | Select-Object Mode, State, ServerType, PartnerServer
$ScopeOutput = Get-DhcpServerv4Scope | Select-Object Name, State
$ScopeStatsOutput = Get-DhcpServerv4ScopeStatistics | Select-Object ScopeID, Free, InUse, Pending, PercentageInUse

# ----------------------------------------------------------------------
# Main Operations
# ----------------------------------------------------------------------

# Check Failover State
if ( $FailoverOutput.State -eq $DesiredFailoverState ) {
    #Write-Host "OK: Failover state is" $FailoverOutput.State
    $FailoverStateExitCode = 0
}
elseif ( $Output.State -ne $DesiredFailoverState ) {
    if ( $FailoverOutput.State -eq $Null ) {
        Write-Host "CRITICAL: Failover state NOT returned!"
        $FailoverStateExitCode = 2
    }
    else {
        Write-Host "CRITICAL: Failover state is" $FailoverOutput.State
        $FailoverStateExitCode = 2
    }
}
if (( $FailoverStateExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
if (( $FailoverStateExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
if (( $FailoverStateExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }

# Check Failover Mode
if ( $FailoverOutput.Mode -eq $DesiredFailoverMode ) {
    #Write-Host "OK: Failover mode is" $FailoverOutput.Mode
    $FailoverModeExitCode = 0
}
elseif ( $FailoverOutput.Mode -ne $DesiredFailoverMode ) {
    if ( $FailoverOutput.Mode -eq $Null ) {
        Write-Host "CRITICAL: Failover mode NOT returned!"
        $FailoverModeExitCode = 2
    }
    else {
        Write-Host "CRITICAL: Failover mode is" $FailoverOutput.Mode
        $FailoverModeExitCode = 2
    }
}
if (( $FailoverModeExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
if (( $FailoverModeExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
if (( $FailoverModeExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }

# Check Scope States
$ExitCodeInc = 1
ForEach ( $Scope in $ScopeOutput ) {
    $ScopeName = $Scope.Name
    $ScopeState = $Scope.State
    $StateExitCodeVar = "StateExitCode" + $ExitCodeInc
    if ( $ScopeState -eq $DesiredScopeState ) {
        #Write-Host "OK:"$ScopeName "is" $DesiredScopeState
        $StateExitCode = 0
    }
    elseif ( $ScopeState -ne $DesiredScopeState ) {
        if ( $ScopeState -eq $Null ) {
            Write-Host "CRITICAL: Scope state NOT returned!"
            $StateExitCode = 2
        }
        else {
        Write-Host "CRITICAL: Scope is" $ScopeState
        $StateExitCode = 2
        }
    }
    if (( $StateExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $StateExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $StateExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }
    $ExitCodeInc++
}

# Check Scope Statistics
$ExitCodeInc = 1
ForEach ( $Stat in $ScopeStatsOutput ) {
    $StatScopeID = $Stat.ScopeID
    $StatFree = $Stat.Free
    $StatInUse = $Stat.InUse
    $StatPending = $Stat.Pending
    $StatPercentInUse = $Stat.PercentageInUse
    $StatExitCodeVar = "StatExitCode" + $ExitCodeInc
    if (( $StatPercentInUse -lt $ScopePercentInUse_HighWarning ) -and ( $StatPercentInUse -gt $ScopePercentInUse_LowWarning )) {
        #Write-Host "OK: Scope" $StatScopeID "use is" $StatPercentInUse"%"
        $StatExitCode = 0
    }
    elseif (( $StatPercentInUse -ge $ScopePercentInUse_HighWarning ) -and ( $StatPercentInUse -lt $ScopePercentInUse_HighCritical )) {
        Write-Host "WARNING: Scope" $StatScopeID "use is" $StatPercentInUse"%"
        $StatExitCode = 1
    }
    elseif ( $StatPercentInUse -ge $ScopePercentInUse_HighCritical ) {
        Write-Host "CRITICAL: Scope " $StatScopeID "use is" $StatPercentInUse"%"
        $StatExitCode = 2
    }
    elseif (( $StatPercentInUse -le $ScopePercentInUse_LowWarning ) -and ( $StatPercentInUse -gt $ScopePercentInUse_LowCritical )) {
        Write-Host "WARNING: Scope" $StatScopeID "use is" $StatPercentInUse"%"
        $StatExitCode = 1
    }
    elseif ( $StatPercentInUse -le $ScopePercentInUse_LowCritical ) {
        Write-Host "CRITICAL: Scope " $StatScopeID "use is" $StatPercentInUse"%"
        $StatExitCode = 2
    }
    elseif ( $StatPercentInUse -eq $Null ) {
        Write-Host "CRITICAL: Scope usage NOT returned!"
        $StatExitCode = 2
    }
    if (( $StatExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $StatExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $StatExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }
    $ExitCodeInc++
}

#Check DhcpFailoverAutoConfigSyncTool status
if (Get-ScheduledTask -TaskName DhcpFailoverAutoConfigSyncTool -ErrorAction Ignore) {
    if (((Get-ScheduledTask -TaskName DhcpFailoverAutoConfigSyncTool)).State -eq "Running") {
        #Write-Host "OK : DhcpFailoverAutoConfigSyncTool scheduled task is in a 'Running' state"
        $TaskExitCode = 0
    }
    else {
        Write-Host "CRITICAL : DhcpFailoverAutoConfigSyncTool scheduled task is not in a 'Running' state"
        $TaskExitCode = 2
    }
}
else {
    Write-Host "CRITICAL : DhcpFailoverAutoConfigSyncTool scheduled task was not found"
    $TaskExitCode = 2
}
if (( $TaskExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
if (( $TaskExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }

#Evaluate final exit code result for all passed checks.
if ($exitcode -eq 0) {Write-Host "OK : Failover state, failover mode, scope states, scope statistics, and DHCP config sync tool are operating within bounds."}
    
exit $exitcode
