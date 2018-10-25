<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "aergo"; ExtraArgs="--opencl-launch 19x128" } # invalid share on zpool
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd"; ExtraArgs="--opencl-launch 19x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11"; ExtraArgs="--opencl-launch 17x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "exosis"; ExtraArgs="--opencl-launch 19x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "geek"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hex"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725"; ExtraArgs="--opencl-launch 18x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi"; ExtraArgs="--opencl-launch 18x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "renesis"; ExtraArgs="--opencl-launch 21x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunkhash"; ExtraArgs="--opencl-launch 20x0 --opencl-threads 2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa"; ExtraArgs="--opencl-launch 19x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus"; ExtraArgs="--opencl-launch 21x0" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s"; ExtraArgs="--opencl-launch 20x128" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17"; ExtraArgs="--opencl-launch 20x0" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22i"; ExtraArgs="--opencl-launch 19x128" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$add = [string]::Empty
				if ($extrargs -notmatch "--opencl-threads") {
					$add = Get-Join " " @($add, "--opencl-threads 3")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig"
					URI = "http://mindminer.online/miners/AMD/wildrig-multi-01251.zip"
					Path = "$Name\wildrig.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) --opencl-platform=$([Config]::AMDPlatformId) --api-port=4028 $add $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 2
				}
			}
		}
	}
}