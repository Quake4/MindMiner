<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		# reject stratum [AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash"; ExtraArgs="-X 4608 -g 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonight"; ExtraArgs="--rawintensity 512 -w 4 -g 2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash"; ExtraArgs="-I 16" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "equihash"; ExtraArgs="-I 16 -g 2" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs="-I 14" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "neoscrypt"; ExtraArgs="-I 16" } # max intensity
	)
})

if (!$Cfg.Enabled) { return }

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
					URI = "https://github.com/zawawawa/gatelessgate/releases/download/v0.1.3-pre6b/gatelessgate-0.1.3-pre6b-win64.zip"
					Path = "$Name\gatelessgate.exe"
					ExtraArgs = $extrargs
					Arguments = "-k $($_.Algorithm) -o stratum+tcp://$($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-listen --gpu-platform $([Config]::AMDPlatformId) $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				}
			}
		}
	}
}