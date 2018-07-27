<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 19" } #570?
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 22" } #580
		#[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel10"; ExtraArgs="-I 25" } #vega?
)})

if (!$Cfg.Enabled) { return }

if ([Config]::Is64Bit -eq $true) {
	$file = "sgminer-x64.exe"
}
else {
	$file = "sgminer.exe"
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "sgminer"
					URI = "https://github.com/Quake4/MindMinerPrerequisites/raw/master/AMD/sgminer-bitcore/sgminer-bitcore-5.6.1.9.zip"
					Path = "$Name\$file"
					ExtraArgs = $extrargs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-listen --gpu-platform $([Config]::AMDPlatformId) $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}