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
. .\Code\Get-AMDPlatformId.ps1
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
. .\Code\Get-RateInfo.ps1
. .\Code\Get-FormatOutput.ps1
. .\Code\Start-ApiServer.ps1

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
	# check asics
	if ($AllAlgos.Disabled -and $AllAlgos.Disabled -contains $algo) { $null }
	# filter by user defined algo
	elseif ((!$AllAlgos.EnabledAlgorithms -or $AllAlgos.EnabledAlgorithms -contains $algo) -and $AllAlgos.DisabledAlgorithms -notcontains $algo) { $algo }
	else { $null }
}

function Set-Stat (
	[Parameter(Mandatory)] [string] $Filename,
	[string] $Key = [string]::Empty,
	[Parameter(Mandatory)] [decimal] $Value,
	[string] $Interval,
	[decimal] $MaxPercent) {
	# fix very high value
	$val = $Statistics.GetValue($Filename, $Key) * [Config]::MaxTrustGrow
	if ($val -gt 0 -and $Value -gt $val) { $Value = $val }
	if ($MaxPercent) {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval, $MaxPercent)
	}
	else {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval)
	}
}

function ReadOrCreateConfig(
	[Parameter(Mandatory)] [string] $EnableQuestion,
	[Parameter(Mandatory)] [string] $Filename,
	[Parameter(Mandatory)] $Config) {
	if ([BaseConfig]::Exists($Filename)) {
		[BaseConfig]::Read($Filename)
	}
	elseif ($global:HasConfirm -eq $true) {
		if (![string]::IsNullOrWhiteSpace($EnableQuestion)) {
			Write-Host "$EnableQuestion (Yes/No)?: " -NoNewline
			[ConsoleKeyInfo] $y = [Console]::ReadKey($true)
			$Config.Enabled = ($y.Key -eq [ConsoleKey]::Y)
			if ($Config.Enabled) { Write-Host "Yes" -NoNewline -ForegroundColor Green }
			else { Write-Host "No" -NoNewline -ForegroundColor Red }
			Write-Host " Thanks"
		}
		[BaseConfig]::ReadOrCreate($Filename, $Config)
	}
	else {
		$global:NeedConfirm = $true
	}
}

function Get-CCMinerStatsAvg (
	[Parameter(Mandatory)] [string] $algo, # Get-Algo
	[Parameter(Mandatory)] $info # AlgoInfo or AlgoInfoEx
) {
	[hashtable] $vals = @{
		"Bitcore" = "-N 3"; "C11" = "-N 3"; "Hsr" = "-N 3"; "Phi" = "-N 1"; "Skein" = "-N 3"; "Skunk" = "-N 5";
		"Timetravel" = "-N 5"; "Tribus" = "-N 1"; "Lyra2re2" = "-N 1"; "Lyra2z" = "-N 1";
		"X11Gost" = "-N 3"; "X16r" = "-N 3"; "X16s" = "-N 3"; "X17" = "-N 1"
	}

	if (!$algo -or !$info) { [ArgumentNullException]::new("Get-CCMinerStatsAvg") }
	[string] $result = [string]::Empty
	if (!$info -or ($info -and (!$info.ExtraArgs -or ($info.ExtraArgs -and !$info.ExtraArgs.Contains("-N "))))) {
		if ($vals.$algo) {
			$result = $vals.$algo
		}
	}
	Remove-Variable vals
	$result
}

function Get-Join(
	[Parameter(Mandatory)] [string] $separator,
	[array] $items
) {
	[string] $result = [string]::Empty
	$items | ForEach-Object {
		if (![string]::IsNullOrWhiteSpace($_)) {
			if (![string]::IsNullOrWhiteSpace($result)) {
				$result += $separator
			}
			$result += $_
		}
	}
	$result
}