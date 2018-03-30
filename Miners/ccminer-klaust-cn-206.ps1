<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>
<#
# no api - no read speed

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 60
})

if (!$Cfg.Enabled) { return }

$Algo = Get-Algo("cryptonight")
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
			API = "ccminer"
			URI = "https://github.com/KlausT/ccminer-cryptonight/releases/download/2.06/ccminer-cryptonight-206-x64-cuda9.zip"
			Path = "$Name\ccminer-cryptonight.exe"
			ExtraArgs = $_.ExtraArgs
			Arguments = "-o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) $N $($_.ExtraArgs)"
			Port = 4068
			BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
		}
	}
}
#>