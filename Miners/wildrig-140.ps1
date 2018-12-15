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
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aergo" } # kl faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" } # kl faster
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "dedal" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "exosis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "geek" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2vc0ban" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "skunkhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x18" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x20r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x21s" }
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
					if ($_.Algorithm -eq "phi" -or $_.Algorithm -eq "renesis" -or $_.Algorithm -eq "skunkhash") { $add = Get-Join " " @($add, "--opencl-threads 3") }
					elseif ($_.Algorithm -eq "lyra2v3") { $add = Get-Join " " @($add, "--opencl-threads 1")	}
					else { $add = Get-Join " " @($add, "--opencl-threads 2") }
				}
				if ($extrargs -notmatch "--opencl-launch") {
					$opencl = [string]::Empty
					switch ($_.Algorithm) {
						"aergo" { $opencl = "17x0" }
						"bitcore" { $opencl = "19x0" }
						"c11" { $opencl = "19x0" }
						"geek" { $opencl = "20x128" }
						"hex" { $opencl = "22x0" }
						"hmq1725" { $opencl = "20x128" }
						"lyra2v3" { $opencl = "23x0" }
						"phi" { $opencl = "19x0" }
						"renesis" { $opencl = "18x128" }
						"skunkhash" { $opencl = "18x0" }
						"sonoa" { $opencl = "18x0" }
						"timetravel" { $opencl = "17x128" }
						"tribus" { $opencl = "21x0" }
						"x22i" { $opencl = "18x0" }
						default { $opencl = "20x0" }
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
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.14.0/wildrig-multi-0.14.0-beta.7z"
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