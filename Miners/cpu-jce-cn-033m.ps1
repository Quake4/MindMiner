<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::CPU) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 30
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonight" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cryptonightv7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8" }
)}

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
				$add = [string]::Empty
				if ($extrargs -notmatch "--variation") {
					switch ($_.Algorithm) {
						"cryptonight" { $add = Get-Join " " @($add, "--variation 1") }
						"cryptonightv7" { $add = Get-Join " " @($add, "--variation 3") }
						"cryptonightheavy" { $add = Get-Join " " @($add, "--variation 5") }
						"cryptonightv8" { $add = Get-Join " " @($add, "--variation 15") }
					}
				}
				if (!$extrargs.Contains("-c ")) { $add = Get-Join " " @($add, "--auto") }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::CPU
					API = "jce"
					URI = "https://github.com/jceminer/cn_cpu_miner/raw/master/jce_cn_cpu_miner.windows.033m.zip"
					Path = "$Name\$file"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --low --forever --any --mport 4046 $add $extrargs"
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
