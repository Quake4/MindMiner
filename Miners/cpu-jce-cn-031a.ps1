<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 30
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight"; ExtraArgs = "--variation 1" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7"; ExtraArgs = "--variation 3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy"; ExtraArgs = "--variation 5" }
)})

if (!$Cfg.Enabled) { return }

$file = if ([Config]::Is64Bit -eq $true) { "jce_cn_cpu_miner64.exe" } else { "jce_cn_cpu_miner32.exe" }
$fee = if ([Config]::Is64Bit -eq $true -and [Config]::CPUFeatures.Contains("AES")) { 1.5 } else { 3 }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				if (!$extrargs.Contains("-c")) { $extrargs = Get-Join " " @("--auto", $extrargs) }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "jce"
					URI = "https://github.com/jceminer/cn_cpu_miner/raw/master/jce_cn_cpu_miner.windows.031a.zip"
					Path = "$Name\$file"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --low --forever --any --mport 4046 $extrargs"
					Port = 4046
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}