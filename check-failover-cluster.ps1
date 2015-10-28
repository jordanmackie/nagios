#Check to make sure that The SameSubnetThreshold Value is set properly

function CheckThreshold 
{
    $exitcode = 0
    $threshold = 60
    $ThresholdExitCode = @()

    try 
    { 
        if  ((((Get-Cluster -ErrorAction 'silentlycontinue' |
                        Format-List -Property *SameSubnetThreshold* |
        Out-String).split(':')[1]).trim()) -eq $threshold)
        {
            $ThresholdExitCode += '0'
        }
        else 
        {
            Write-Host -Object 'WARNING : SameSubnetThreshold value is incorrect' -ForegroundColor Red
            $ThresholdExitCode += '1'
        }
    }
  
    Catch 
    {
        Write-Host -Object 'WARNING : Failed to obtain Threshold value' -ForegroundColor Red
        $ThresholdExitCode = '1'
    }

    $exitcode = ($ThresholdExitCode | Measure-Object -Maximum).Maximum

    return $exitcode
}

#Check all cluster node states
function CheckClusterNodes 
{
    $exitcode = 0
    $NodeExitCode = @()

    Get-ClusterNode -ErrorAction SilentlyContinue | ForEach-Object -Process {
        if (($_.State) -eq 'Up') 
        {
            #Write-Host "OK :" $_.Name "node state is :" $_.State  -ForegroundColor Green
            $NodeExitCode += '0'
        }
        elseif (($_.State) -eq 'Paused') 
        {
            Write-Host 'WARNING :' $_.Name 'node state is :' $_.State  -ForegroundColor Yellow
            $NodeExitCode += '1'
        }
        elseif (($_.State) -eq 'Down') 
        {
            Write-Host 'CRITICAL :' $_.Name 'node state is :' $_.State  -ForegroundColor Red
            $NodeExitCode += '2'
        }
    }

    $exitcode = ($NodeExitCode | Measure-Object -Maximum).Maximum 

    return $exitcode
}

#Check all cluster resource states
function CheckClusterResources 
{
    $exitcode = 0
    $ResourceExitCode = @()
    $AllClusterResources = Get-ClusterResource -ErrorAction SilentlyContinue
    $PercentIPAddressesOnline = .5

    $AllClusterResources |
    Where-Object -FilterScript {
        $_.ResourceType -ne 'Ip Address'
    } |
    ForEach-Object -Process {
        if (($_.State) -eq 'Online') 
        {
            #Write-Host "OK :" $_.Name "resource state is :" $_.State  -ForegroundColor Green
            $ResourceExitCode += '0'
        }
        else  
        {
            Write-Host 'CRITICAL :' $_.Name 'resource state is :' $_.State  -ForegroundColor Red

            $ResourceExitCode += '2'
        }
    }
    
    $ClusterIPCollectionExpected = ($AllClusterResources |
        Where-Object -FilterScript {
            $_.ResourceType -eq 'IP Address'
        } |
    Group-Object -Property OwnerGroup).Group.Count
    $ClusterIPCollectionActual = ($AllClusterResources |
        Where-Object -FilterScript {
            $_.ResourceType -eq 'IP Address' -AND $_.State -eq 'Online' 
        } |
    Group-Object -Property OwnerGroup).Group.Count

    if ($ClusterIPCollectionActual/$ClusterIPCollectionExpected -ge $PercentIPAddressesOnline)  
    {
        #Write-Host "OK :" $_.Name "resource state is :" $_.State  -ForegroundColor Green
        $ResourceExitCode += '0'
    }
    else 
    {
        $AllClusterResources |
        Where-Object -FilterScript {
            $_.ResourceType -eq 'Ip Address'
        } |
        ForEach-Object -Process {
            Write-Host 'CRITICAL :' $_.Name 'resource state is :' $_.State  -ForegroundColor Red
        }
        $ResourceExitCode += '2'
    }
 
    $exitcode = ($ResourceExitCode | Measure-Object -Maximum).Maximum    

    return $exitcode
}

function CheckClusterService 
{
    $exitcode = 0
    $ServiceExitCode = @()

    if ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Status -eq 'Running') 
    {
        #Write-Host "OK : Cluster Service state is Running. " -ForegroundColor Green
        $ServiceExitCode += '0'
    }
    elseif ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Status -eq 'Stopped') 
    {
        Write-Host -Object 'CRITICAL : Cluster Service state is Stopped. ' -ForegroundColor Red
        $ServiceExitCode += '2'
    }
    elseif ((Get-Service -Name ClusSvc -ErrorAction SilentlyContinue).Count -lt 1) 
    {
        Write-Host -Object 'CRITICAL : Cluster Service is not enumerable. ' -ForegroundColor Red
        $ServiceExitCode += '2'
    }

    $exitcode = ($ServiceExitCode | Measure-Object -Maximum).Maximum 
    
    return $exitcode
}

#Evaluate the check results and return proper exitcode
function EvaluateCheckResults 
{
    $exitcode = 0
    $CheckClusterServiceResult = CheckClusterService

    if ($CheckClusterServiceResult -eq 0) 
    {
        $CheckThresholdValue = CheckThreshold
        $CheckClusterNodesResult = CheckClusterNodes
        $CheckClusterResourcesResult = CheckClusterResources
        $AllExitCodes = "$CheckThresholdValue", "$CheckClusterNodesResult", "$CheckClusterResourcesResult"
        $exitcode = ($AllExitCodes | Measure-Object -Maximum).Maximum
               
        if (( $exitcode -eq 0)) 
        { 
            Write-Host -Object 'OK : All enumerable cluster nodes, resources, and services are up and online. ' -ForegroundColor Green
            $exitcode = 0 
        }
        else 
        {

        }
    }
    else 
    {

    }

    return $exitcode
}

exit EvaluateCheckResults