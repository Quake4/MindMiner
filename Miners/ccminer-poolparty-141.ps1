<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 120
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r" }
)})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$url = "https://github.com/graemes/poolparty-x16r/releases/download/v1.4.1/poolparty-win64-1.4.1.zip"
	$file = "poolparty-x64.exe"
}
else {
	$url = "https://github.com/graemes/poolparty-x16r/releases/download/v1.4.1/poolparty-win32-1.4.1.zip"
	$file = "poolparty-x32.exe"
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = if ($Algo -match "x16.") { "ccminer_woe" } else { "ccminer" }
					URI = $url
					Path = "$Name\$file"
					ExtraArgs = $_.ExtraArgs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) $N --no-simple-hr --donate 0 --api-bind=4068 $($_.ExtraArgs)"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}