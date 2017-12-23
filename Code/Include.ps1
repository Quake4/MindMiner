<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\WebRequest.ps1
. .\Code\SummaryInfo.ps1
. .\Code\AlgoInfo.ps1
. .\Code\PoolInfo.ps1
. .\Code\MinerInfo.ps1
. .\Code\BaseConfig.ps1
. .\Code\Get-CPUFeatures.ps1
. .\Code\Get-ManagementObject.ps1
. .\Code\Config.ps1
. .\Code\MinerProfitInfo.ps1
. .\Code\HumanInterval.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\MinerProcess.ps1
. .\Code\Get-Prerequisites.ps1
. .\Code\Get-Config.ps1
. .\Code\Get-Speed.ps1
. .\Code\Get-CPUMask.ps1
. .\Code\Update-Miner.ps1
. .\Code\Get-PoolInfo.ps1

function Get-Pool {
	param(
		[Parameter(Mandatory = $true)]
		[string] $algorithm
	)	
	$pool = $AllPools | Where-Object -Property Algorithm -eq $algorithm | Select-Object -First 1
	if ($pool) { $pool } else { $null }
}

function Get-Algo {
	param(
		[Parameter(Mandatory = $true)]
		[string] $algorithm
	)
	if ($AllAlgos.Mapping.$algorithm) { $algo = $AllAlgos.Mapping.$algorithm }
	else { $algo = (Get-Culture).TextInfo.ToTitleCase($algorithm) }
	if ($AllAlgos.Disabled -and $AllAlgos.Disabled.Contains($algo.ToLower())) { $null }
	else { $algo }
}

function Set-Stat (
	[Parameter(Mandatory)] [string] $Filename,
	[string] $Key = [string]::Empty,
	[Parameter(Mandatory)] [decimal] $Value,
	[string] $Interval,
	[decimal] $MaxPercent) {
	if ($MaxPercent) {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval, $MaxPercent)
	}
	else {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval)
	}
}