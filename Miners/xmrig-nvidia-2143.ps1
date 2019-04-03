<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptolight" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightheavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv7" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightv8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cryptonightr" }
)}

if (!$Cfg.Enabled) { return }

$file = [IO.Path]::Combine($BinLocation, $Name, "config.json")
if ([IO.File]::Exists($file)) {
	[IO.File]::Delete($file)
}

switch ([Config]::CudaVersion) {
	{ $_ -ge [version]::new(10, 1) } { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda10_1-win64.zip" }
	([version]::new(10, 0)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda10-win64.zip" }
	([version]::new(9, 2)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda9_2-win64.zip" }
	([version]::new(9, 1)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda9_1-win64.zip" }
	([version]::new(9, 0)) { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda9_0-win64.zip" }
	default { $url = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda8-win64.zip" }
}

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$add = [string]::Empty
				if ($extrargs -notmatch "--variant") {
					$add = "--variant 1"
					if ($_.Algorithm -eq "cryptonightv8") {
						$add = "--variant 2"
					}
					elseif ($_.Algorithm -eq "cryptonightr") {
						$add = "--variant 4"
					}
				}
				if ($extrargs -notmatch "-a ") {
					switch ($_.Algorithm) {
						"cryptolight" { $add = Get-Join " " @($add, "-a cryptonight-lite") }
						"cryptonightv7" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightv8" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightr" { $add = Get-Join " " @($add, "-a cryptonight") }
						"cryptonightheavy" { $add = Get-Join " " @($add, "-a cryptonight-heavy") }
					}
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "xmrig"
					URI = $url
					Path = "$Name\xmrig-nvidia.exe"
					ExtraArgs = $extrargs
					Arguments = "-o $($Pool.Host):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) --api-port=4043 --donate-level=1 -R $($Config.CheckTimeout) $add $extrargs"
					Port = 4043
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = 1
				}
			}
		}
	}
}