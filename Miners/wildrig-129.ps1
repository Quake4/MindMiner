<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "aergo"; ExtraArgs="--opencl-launch 19x128" } # invalid share on zpool
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "c11" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "exosis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "geek" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunkhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x22i" }
)}

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
					switch ($_.Algorithm) {
						($_ -eq "skunkhash" -or $_ -eq "x22i" -or $_ -eq "geek") { $add = Get-Join " " @($add, "--opencl-threads 2") }
						default { $add = Get-Join " " @($add, "--opencl-threads 3") }
					}
				}
				if ($extrargs -notmatch "--opencl-launch") {
					$opencl = [string]::Empty
					switch ($_.Algorithm) {
						"bcd" { $opencl = "20x128" }
						"c11" { $opencl = "18x128" }
						"hex" { $opencl = "21x0" }
						"phi" { $opencl = "19x0" }
						"renesis" { $opencl = "20x0" }
						"skunkhash" { $opencl = "20x0" }
						"tribus" { $opencl = "20x128" }
						"x16r" { $opencl = "18x128" }
						"x16s" { $opencl = "18x128" }
						"x17" { $opencl = "20x128" }
						"x22i" { $opencl = "19x0" }
						default { $opencl = "19x128" }
					}
					$add = Get-Join " " @($add, "--opencl-launch", $opencl)
					Remove-Variable opencl
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "xmrig"
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.12.9/wildrig-multi-0.12.9-beta.7z"
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