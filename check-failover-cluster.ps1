#Check all cluster node states
function CheckClusterNodes {
    $exitcode = 0
    Get-ClusterNode -ErrorAction SilentlyContinue | % {

    if (($_.State) -eq "Up") {
         #Write-Host "OK :" $_.Name "node state is :" $_.State -ForegroundColor Green
         $NodeExitCode = 0
         }
    elseif (($_.State) -eq "Paused") {
         Write-Host "WARNING :" $_.Name "node state is :" $_.State -ForegroundColor Yellow
         $NodeExitCode = 1
         }
    elseif (($_.State) -eq "Down") {
         Write-Host "CRITICAL :" $_.Name "node state is :" $_.State -ForegroundColor Red
         $NodeExitCode = 2
         }

    
    if (( $NodeExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $NodeExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $NodeExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }
    
    }
return $exitcode
}

#Check all cluster resource states
function CheckClusterResources {
    $exitcode = 0
    Get-ClusterResource -ErrorAction SilentlyContinue | % {
    if (($_.State) -eq "Online") {
         #Write-Host "OK :" $_.Name "resource state is :" $_.State -ForegroundColor Green
         $ResourceExitCode = 0
         }
    else  {
         Write-Host "CRITICAL :" $_.Name "resource state is :" $_.State -ForegroundColor Red
         $ResourceExitCode = 2
         }
     }
    
    if (( $ResourceExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $ResourceExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $ResourceExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }

return $exitcode
}

function CheckClusterService {
    $exitcode =0
    if ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Status -eq "Running") {
        #Write-Host "OK : Cluster Service state is Running." -ForegroundColor Green
        $ServiceExitCode = 0
        }
    elseif ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Status -eq "Stopped") {
        Write-Host "CRITICAL : Cluster Service state is Stopped." -ForegroundColor Red
        $ServiceExitCode = 2
        }
    elseif ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Count -lt 1) {
        Write-Host "CRITICAL : Cluster Service is is not enumerable." -ForegroundColor Red
        $ServiceExitCode = 2
        }
 
    if (( $ServiceExitCode -eq 0 ) -and ( $exitcode -eq 0 )) { $exitcode = 0 }
    if (( $ServiceExitCode -eq 1 ) -and ( $exitcode -le 1 )) { $exitcode = 1 }
    if (( $ServiceExitCode -eq 2 ) -and ( $exitcode -le 2 )) { $exitcode = 2 }

return $exitcode
}

#Evaluate the check results and return proper exitcode
function EvaluateCheckResults {
    $exitcode = 0
    $CheckClusterServiceResult = CheckClusterService

        if ($CheckClusterServiceResult -eq 0) {
    
    $CheckClusterNodesResult = CheckClusterNodes
    $CheckClusterResourcesResult = CheckClusterResources
    
            if (( $CheckClusterNodesResult -eq 0 ) -and ( $CheckClusterResourcesResult -eq 0 )) { 
                Write-Host "OK : All enumerable cluster nodes, resources, and services are up and online." -ForegroundColor Green
                $exitcode = 0 
                }
            if (( $CheckClusterNodesResult -eq 1 ) -and ( $CheckClusterResourcesResult -le 1 )) { $exitcode = 1 }
            if (( $CheckClusterResourcesResult -eq 1 ) -and ( $CheckClusterNodesResult -le 1 )) { $exitcode = 1 }
            if (( $CheckClusterNodesResult -eq 2 ) -and ( $CheckClusterResourcesResult -le 2 )) { $exitcode = 2 }
            if (( $CheckClusterResourcesResult -eq 2 ) -and ( $CheckClusterNodesResult -le 2 )) { $exitcode = 2 }
            }
        else {$exitcode = 2}
            
return $exitcode
}s

exit EvaluateCheckResults