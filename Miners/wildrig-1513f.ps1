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
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-astralhash" } # all rejected
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-jeonghash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-padihash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "glt-pawelhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "aergo" } # kl faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bcd" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "bitcore" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "c11" } # kl faster
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "dedal" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "exosis" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "geek" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hex" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "hmq1725" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "lyra2vc0ban" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "phi" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "polytimos" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "renesis" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sha256q" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sha256t" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "skunkhash" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "sonoa" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "timetravel" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "tribus" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x16s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x17" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x18" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x20r" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x21s" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "x22i" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool -and ($Pool.Name -notmatch "nicehash" -or ($Pool.Name -match "nicehash" -and $_.Algorithm -notmatch "mtp"))) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$add = [string]::Empty
				if ($extrargs -notmatch "--opencl-threads") {
					if ($_.Algorithm -eq "phi" -or $_.Algorithm -eq "renesis" -or $_.Algorithm -eq "skunkhash") { $add = Get-Join " " @($add, "--opencl-threads 3") }
					elseif ($_.Algorithm -eq "lyra2v3" -or $_.Algorithm -eq "sha256q" -or $_.Algorithm -eq "sha256t") { $add = Get-Join " " @($add, "--opencl-threads 1")	}
					else { $add = Get-Join " " @($add, "--opencl-threads 2") }
				}
				if ($extrargs -notmatch "--opencl-launch") {
					$opencl = [string]::Empty
					switch ($_.Algorithm) {
						"aergo" { $opencl = "17x0" }
						"bitcore" { $opencl = "19x0" }
						"c11" { $opencl = "19x0" }
						"hex" { $opencl = "22x0" }
						"hmq1725" { $opencl = "20x128" }
						"lyra2v3" { $opencl = "23x0" }
						"phi" { $opencl = "19x0" }
						"renesis" { $opencl = "18x128" }
						"sha256q" { $opencl = "29x0" }
						"sha256t" { $opencl = "29x0" }
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
					URI = "https://github.com/andru-kun/wildrig-multi/releases/download/0.15.1/wildrig-multi-windows-0.15.1.3-beta.7z"
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