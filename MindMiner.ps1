<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Out-Data.ps1

Out-Iam
Write-Host "Loading ..." -ForegroundColor Green

$global:HasConfirm = $false
$global:NeedConfirm = $false
$global:AskPools = $false
$global:API = [hashtable]::Synchronized(@{})

. .\Code\Include.ps1

# ctrl+c hook
[Console]::TreatControlCAsInput = $true
[Console]::Title = "MindMiner $([Config]::Version.Replace("v", [string]::Empty))"

$BinLocation = [IO.Path]::Combine($(Get-Location), [Config]::BinLocation)
New-Item $BinLocation -ItemType Directory -Force | Out-Null
$BinScriptLocation = [scriptblock]::Create("Set-Location('$BinLocation')")
$DownloadJob = $null

# download prerequisites
Get-Prerequisites ([Config]::BinLocation)

# read and validate config
$Config = Get-Config

if (!$Config) { exit }

if ($Config.DevicesStatus) {
	$Devices = Get-Devices ([Config]::ActiveTypes)
}

[SummaryInfo] $Summary = [SummaryInfo]::new([Config]::RateTimeout)
$Summary.TotalTime.Start()

Clear-Host
Out-Header

$ActiveMiners = [Collections.Generic.Dictionary[string, MinerProcess]]::new()
[StatCache] $Statistics = [StatCache]::Read([Config]::StatsLocation)
if ($Config.ApiServer) {
	if ([Net.HttpListener]::IsSupported) {
		if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			Write-Host "Starting API server at port $([Config]::ApiPort) for Remote access ..." -ForegroundColor Green
		}
		else {
			Write-Host "Starting API server at port $([Config]::ApiPort) for Local access ..." -ForegroundColor Green
			Write-Host "To start API server for remote access run MindMiner as Administrator." -ForegroundColor Yellow
		}
		Start-ApiServer
	}
	else {
		Write-Host "Http listner not supported. Can't start API server." -ForegroundColor Red
	}
}

if ($global:API.Running) {
	$global:API.Worker = $Config.WorkerName
	$global:API.Config = $Config.Web() | ConvertTo-Html -Fragment
}

# FastLoop - variable for benchmark or miner errors - very fast switching to other miner - without ask pools and miners
[bool] $FastLoop = $false 
# exit - var for exit
[bool] $exit = $false
# main loop
while ($true)
{
	if ($Summary.RateTime.IsRunning -eq $false -or $Summary.RateTime.Elapsed.TotalSeconds -ge [Config]::RateTimeout.TotalSeconds) {
		$Rates = Get-RateInfo
		$exit = Update-Miner ([Config]::BinLocation)
		if ($exit -eq $true) {
			$FastLoop = $true
		}
		$Summary.RateTime.Reset()
		$Summary.RateTime.Start()
	}
	elseif (!$Rates -or $Rates.Count -eq 0) {
		$Rates = Get-RateInfo
	}

	if (!$FastLoop) {
		# read algorithm mapping
		$AllAlgos = [BaseConfig]::ReadOrCreate("algorithms.txt", @{
			EnabledAlgorithms = $null
			DisabledAlgorithms = $null
			Difficulty = $null
			RunBefore = $null
			RunAfter = $null
		})
		# how to map algorithms
		$AllAlgos.Add("Mapping", [ordered]@{
			"argon2d250" = "Argon2-crds"
			"argon2d-crds" = "Argon2-crds"
			"argon2d500" = "Argon2-dyn"
			"argon2d-dyn" = "Argon2-dyn"
			"binarium_hash_v1" = "Binarium-V1"
			"blakecoin" = "Blake"
			"blake256r8" = "Blake"
			"cnheavy" = "Cryptonightheavy"
			"cnv7" = "Cryptonightv7"
			"cnv8" = "Cryptonightv8"
			"cryptonight_heavy" = "Cryptonightheavy"
			"cryptonight_lite_v7" = "Cryptolightv7"
			"cryptonight-monero" = "Cryptonightv8"
			"cryptonight_v7" = "Cryptonightv7"
			"cryptonight_v8" = "Cryptonightv8"
			"cryptonight_r" = "Cryptonightr"
			"cuckaroo29" = "Grin29"
			"cuckatoo31" = "Grin31"
			"Grin" = "Grin29"
			"GrinCuckaroo29" = "Grin29"
			"GrinCuckatoo31" = "Grin31"
			"dagger" = "Ethash"
			"daggerhashimoto" = "Ethash"
			"Equihash-BTG" = "EquihashBTG"
			"equihashBTG" = "EquihashBTG"
			"glt-astralhash" = "Astralhash"
			"glt-jeonghash" = "Jeonghash"
			"glt-padihash" = "Padihash"
			"glt-pawelhash" = "Pawelhash"
			"lyra2rev2" = "Lyra2re2"
			"lyra2r2" = "Lyra2re2"
			"lyra2v2" = "Lyra2re2"
			"lyra2v2-old" = "Lyra2re2"
			"lyra2rev3" = "Lyra2v3"
			"lyra2re3" = "Lyra2v3"
			"lyra2r3" = "Lyra2v3"
			# "monero" = "Cryptonightv7"
			"m7m" = "M7M"
			"neoscrypt" = "NeoScrypt"
			"poly" = "Polytimos"
			"sib" = "X11Gost"
			"sibcoin" = "X11Gost"
			"sibcoin-mod" = "X11Gost"
			"skeincoin" = "Skein"
			"skunkhash" = "Skunk"
			"x11gost" = "X11Gost"
			"x11evo" = "X11Evo"
			"phi1612" = "Phi"
			"timetravel10" = "Bitcore"
			"x13bcd" = "Bcd"
			"x13sm3" = "Hsr"
			"myriad-groestl" = "MyrGr"
			"myriadgroestl" = "MyrGr"
			"myr-gr" = "MyrGr"
			"jackpot" = "JHA"
			"vit" = "Vitalium"
		})
		# disable asic algorithms
		$AllAlgos.Add("Disabled", @("sha256", "sha256asicboost", "sha256-ld", "scrypt", "scrypt-ld", "x11", "x11-ld", "x13", "x14", "x15", "quark", "qubit", "myrgr", "lbry", "decred", "sia", "blake", "nist5", "cryptonight", "cryptonightv7", "x11gost", "groestl", "equihash", "lyra2re2", "pascal"))

		# ask needed pools
		if ($global:AskPools -eq $true) {
			$AllPools = Get-PoolInfo ([Config]::PoolsLocation)
			$global:AskPools = $false
		}
		Write-Host "Pool(s) request ..." -ForegroundColor Green
		$AllPools = Get-PoolInfo ([Config]::PoolsLocation)

		# check pool exists
		if (!$AllPools -or $AllPools.Length -eq 0) {
			Write-Host "No Pools!" -ForegroundColor Red
			Get-Confirm
			continue
		}
		
		Write-Host "Miners request ..." -ForegroundColor Green
		$AllMiners = Get-ChildItem ([Config]::MinersLocation) | Where-Object Extension -eq ".ps1" | ForEach-Object {
			Invoke-Expression "$([Config]::MinersLocation)\$($_.Name)"
		}

		# filter by exists hardware
		$AllMiners = $AllMiners | Where-Object { [Config]::ActiveTypes -contains ($_.Type -as [eMinerType]) }

		# download miner
		if ($DownloadJob -and $DownloadJob.State -ne "Running") {
			$DownloadJob | Remove-Job -Force | Out-Null
			$DownloadJob.Dispose()
			$DownloadJob = $null
		}
		$DownloadMiners = $AllMiners | Where-Object { !$_.Exists([Config]::BinLocation) } | Select-Object Name, Path, URI -Unique
		if ($DownloadMiners -and ($DownloadMiners.Length -gt 0 -or $DownloadMiners -is [PSCustomObject])) {
			Write-Host "Download miner(s): $(($DownloadMiners | Select-Object Name -Unique | ForEach-Object { $_.Name }) -Join `", `") ... " -ForegroundColor Green
			if (!$DownloadJob) {
				$PathUri = $DownloadMiners | Select-Object Path, URI -Unique;
				$DownloadJob = Start-Job -ArgumentList $PathUri -FilePath ".\Code\Downloader.ps1" -InitializationScript $BinScriptLocation
			}
		}

		# check exists miners & update bench timeout by global value
		$AllMiners = $AllMiners | Where-Object { $_.Exists([Config]::BinLocation) } | ForEach-Object {
			if ($Config.BenchmarkSeconds -and $Config.BenchmarkSeconds."$($_.Type)" -gt $_.BenchmarkSeconds) {
				$_.BenchmarkSeconds = $Config.BenchmarkSeconds."$($_.Type)"
			}
			$_
		}
		
		if ($AllMiners.Length -eq 0) {
			Write-Host "No Miners!" -ForegroundColor Red
			Get-Confirm
			continue
		}

		# save speed active miners
		$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Normal } | ForEach-Object {
			$speed = $_.GetSpeed($false)
			if ($speed -gt 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed, 0.25)
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$speed = $_.GetSpeed($true)
					if ($speed -gt 0) {
						$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true), $speed, $Config.AverageHashSpeed, 0.25)
					}
				}
			}
			elseif ($speed -eq 0 -and $_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2)) {
				# no hasrate stop miner and move to nohashe state while not ended
				$_.Stop($AllAlgos.RunAfter)
			}
		}
	}

	# get devices status
	if ($Config.DevicesStatus) {
		$Devices = Get-Devices ([Config]::ActiveTypes) $Devices

		# power draw save
		if (Get-ElectricityPriceCurrency) {
			$Benchs = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and ($_.CurrentTime.Elapsed.TotalSeconds * 2) -ge $_.Miner.BenchmarkSeconds } | ForEach-Object {
				$measure = $Devices["$($_.Miner.Type)"] | Measure-Object Power -Sum
				if ($measure) {
					$draw = [decimal]$measure[0].Sum
					if ($draw -gt 0) {
						$_.SetPower($draw)
						$draw = $Statistics.SetValue($_.Miner.GetPowerFilename(), $_.Miner.GetKey(), $draw, $Config.AverageHashSpeed)
					}
					Remove-Variable draw
				}
				Remove-Variable measure
			}
		}
	}

	# stop benchmark by condition: timeout reached and has result or timeout more then twice and no result
	$Benchs = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running -and $_.Action -eq [eAction]::Benchmark }
	if ($Benchs) { Get-Speed $Benchs } # read speed from active miners
	$Benchs | ForEach-Object {
		$speed = $_.GetSpeed($false)
		if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
			($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
			$_.Stop($AllAlgos.RunAfter)
			if ($speed -eq 0) {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), -1)
			}
			else {
				$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), $speed, $Config.AverageHashSpeed)
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$speed = $_.GetSpeed($true)
					$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true), $speed, $Config.AverageHashSpeed)
				}
			}
		}
	}
	Remove-Variable Benchs
	
	# read speed and price of proposed miners
	$AllMiners = $AllMiners | ForEach-Object {
		if (!$FastLoop) {
			$speed = $Statistics.GetValue($_.GetFilename(), $_.GetKey())
			# filter unused
			if ($speed -ge 0) {
				$price = (Get-Pool $_.Algorithm).Profit
				[MinerProfitInfo] $mpi = $null
				if (![string]::IsNullOrWhiteSpace($_.DualAlgorithm)) {
					$mpi = [MinerProfitInfo]::new($_, $Config, $speed, $price, $Statistics.GetValue($_.GetFilename(), $_.GetKey($true)), (Get-Pool $_.DualAlgorithm).Profit)
				}
				else {
					$mpi = [MinerProfitInfo]::new($_, $Config, $speed, $price)
				}
				if ($Config.DevicesStatus -and (Get-ElectricityPriceCurrency)) {
					$mpi.SetPower($Statistics.GetValue($_.GetPowerFilename(), $_.GetKey()), (Get-ElectricityCurrentPrice "BTC"))
				}
				Remove-Variable price
				$mpi
			}
		}
		elseif (!$exit) {
			$speed = $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey())
			# filter unused
			if ($speed -ge 0) {
				if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) {
					$_.SetSpeed($speed, $Statistics.GetValue($_.Miner.GetFilename(), $_.Miner.GetKey($true)))
				}
				else {
					$_.SetSpeed($speed)
				}
				if ($Config.DevicesStatus -and (Get-ElectricityPriceCurrency)) {
					$_.SetPower($Statistics.GetValue($_.Miner.GetPowerFilename(), $_.Miner.GetKey()), (Get-ElectricityCurrentPrice "BTC"))
				}
				$_
			}
		}
	} |
	# reorder miners for proper output
	Sort-Object @{ Expression = { $_.Miner.Type } }, @{ Expression = { $_.Profit }; Descending = $true }, @{ Expression = { $_.Miner.GetExKey() } }

	if (!$exit) {
		Remove-Variable speed

		if ($global:HasConfirm -and !($AllMiners | Where-Object { $_.Speed -eq 0 } | Select-Object -First 1)) {
			# reset confirm after all bench
			$global:HasConfirm = $false
		}

		$FStart = !$global:HasConfirm -and ($Summary.TotalTime.Elapsed.TotalSeconds / 100 -gt $Summary.FeeTime.Elapsed.TotalSeconds + [Config]::FTimeout)
		$FChange = $false
		if ($FStart -or $Summary.FeeCurTime.IsRunning) {
			if (!$FStart -and $Summary.FeeCurTime.Elapsed.TotalSeconds -gt [Config]::FTimeout * 2) {
				$FChange = $true
				$Summary.FStop()
			}
			elseif (!$Summary.FeeCurTime.IsRunning) {
				$FChange = $true
				$Summary.FStart()
			}
		}
		
		# look for run or stop miner
		[Config]::ActiveTypes | ForEach-Object {
			$type = $_

			# variables
			$allMinersByType = $AllMiners | Where-Object { $_.Miner.Type -eq $type }
			$activeMinersByType = $ActiveMiners.Values | Where-Object { $_.Miner.Type -eq $type }
			$activeMinerByType = $activeMinersByType | Where-Object { $_.State -eq [eState]::Running }
			$activeMiner = if ($activeMinerByType) { $allMinersByType | Where-Object { $_.Miner.GetUniqueKey() -eq $activeMinerByType.Miner.GetUniqueKey() } } else { $null }

			# place current bench
			$run = $null
			if ($activeMinerByType -and $activeMinerByType.Action -eq [eAction]::Benchmark) {
				$run = $activeMinerByType
			}

			# find benchmark if not benchmarking
			if (!$run) {
				$run = $allMinersByType | Where-Object { $_.Speed -eq 0 } | Sort-Object @{ Expression = { $_.Miner.GetExKey() } } | Select-Object -First 1
				if ($global:HasConfirm -eq $false -and $run) {
					$run = $null
					$global:NeedConfirm = $true
				}
			}

			$lf = Get-ProfitLowerFloor $type

			# nothing benchmarking - get most profitable - exclude failed
			if (!$run) {
				$miner = $null
				$allMinersByType | ForEach-Object {
					if (!$run -and $_.Profit -gt $lf) {
						# skip failed or nohash miners
						$miner = $_
						if (($activeMinersByType | 
							Where-Object { ($_.State -eq [eState]::NoHash -or $_.State -eq [eState]::Failed) -and
								$miner.Miner.GetUniqueKey() -eq $_.Miner.GetUniqueKey() }) -eq $null) {
							$run = $_
						}
					}
				}
				Remove-Variable miner
			}

			if ($run -and ($global:HasConfirm -or $FChange -or !$activeMinerByType -or ($activeMinerByType -and !$activeMiner) -or !$Config.SwitchingResistance.Enabled -or
				($Config.SwitchingResistance.Enabled -and ($activeMinerByType.CurrentTime.Elapsed.TotalMinutes -ge $Config.SwitchingResistance.Timeout -or
					($run.Profit * 100 / $activeMiner.Profit - 100) -gt $Config.SwitchingResistance.Percent)))) {
				$miner = $run.Miner
				if (!$ActiveMiners.ContainsKey($miner.GetUniqueKey())) {
					$ActiveMiners.Add($miner.GetUniqueKey(), [MinerProcess]::new($miner, $Config))
				}
				# stop not choosen
				$activeMinersByType | Where-Object { $_.State -eq [eState]::Running -and ($miner.GetUniqueKey() -ne $_.Miner.GetUniqueKey() -or $FChange) } | ForEach-Object {
					$_.Stop($AllAlgos.RunAfter)
				}
				# run choosen
				$mi = $ActiveMiners[$miner.GetUniqueKey()]
				if ($mi.State -eq $null -or $mi.State -ne [eState]::Running) {
					if ($Statistics.GetValue($mi.Miner.GetFilename(), $mi.Miner.GetKey()) -eq 0 -or $FStart) {
						$mi.Benchmark($FStart, $AllAlgos.RunBefore)
					}
					else {
						$mi.Start($AllAlgos.RunBefore)
					}
					$FastLoop = $false
				}
				Remove-Variable mi, miner
			}
			elseif ($run -and $activeMinerByType -and $activeMiner -and $Config.SwitchingResistance.Enabled -and
				$run.Miner.GetUniqueKey() -ne $activeMinerByType.Miner.GetUniqueKey() -and
				!($activeMinerByType.CurrentTime.Elapsed.TotalMinutes -gt $Config.SwitchingResistance.Timeout -or
				($run.Profit * 100 / $activeMiner.Profit - 100) -gt $Config.SwitchingResistance.Percent)) {
				$run.SwitchingResistance = $true
			}
			elseif (!$run -and $lf) {
				# stop if lower floor
				$activeMinersByType | Where-Object { $_.State -eq [eState]::Running -and $_.Profit -lt $lf } | ForEach-Object {
					$_.Stop($AllAlgos.RunAfter)
				}
			}
			Remove-Variable lf, run, activeMiner, activeMinerByType, activeMinersByType, allMinersByType, type
		}

		if ($global:API.Running) {
			$global:API.MinersRunning = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersWeb) | ConvertTo-Html -Fragment
			$global:API.ActiveMiners = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersApi)
		}

		if (!$FastLoop -and ![string]::IsNullOrWhiteSpace($Config.ApiKey)) {
			Write-Host "Send data to online monitoring ..." -ForegroundColor Green
			$json = Get-JsonForMonitoring
			$str = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
			$json = Get-UrlAsJson "http://api.mindminer.online/?type=setworker&apikey=$($Config.ApiKey)&worker=$($Config.WorkerName)&data=$str"
			if ($json -and $json.error) {
				Write-Host "Error send state to online monitoring: $($json.error)" -ForegroundColor Red
				Start-Sleep -Seconds ($Config.CheckTimeout)
			}
			Remove-Variable str, json
		}
	}

	$Statistics.Write([Config]::StatsLocation)

	if (!$FastLoop) {
		$Summary.LoopTime.Reset()
		$Summary.LoopTime.Start()
	}

	$verbose = $Config.Verbose -as [eVerbose]

	Clear-Host
	Out-Header ($verbose -ne [eVerbose]::Minimal)

	if ($Config.DevicesStatus) {
		Out-DeviceInfo ($verbose -eq [eVerbose]::Minimal)
	}

	if ($verbose -eq [eVerbose]::Full) {
		Out-PoolInfo
	}
	
	$mult = if ($verbose -eq [eVerbose]::Normal) { 0.65 } else { 0.80 }
	$alg = [hashtable]::new()
	Out-Table ($AllMiners | Where-Object {
		$uniq =  $_.Miner.GetUniqueKey()
		$type = $_.Miner.Type
		if (!$alg[$type]) { $alg[$type] = [Collections.ArrayList]::new() }
		$_.Speed -eq 0 -or ($_.Profit -ge 0.00000001 -and ($verbose -eq [eVerbose]::Full -or
			($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped -and $_.Miner.GetUniqueKey() -eq $uniq } | Select-Object -First 1) -or
				($_.Profit -ge (($AllMiners | Where-Object { $_.Miner.Type -eq $type } | Select-Object -First 1).Profit * $mult) -and
					$alg[$type] -notcontains "$($_.Miner.Algorithm)$($_.Miner.DualAlgorithm)")))
		$ivar = $alg[$type].Add("$($_.Miner.Algorithm)$($_.Miner.DualAlgorithm)")
		Remove-Variable ivar, type, uniq
	} |
	Format-Table (Get-FormatMiners) -GroupBy @{ Label="Type"; Expression = { $_.Miner.Type } })
	Write-Host "+ Running, - No Hash, ! Failed, % Switching Resistance, * Specified Coin, ** Solo, _ Low Profit"
	Write-Host
	Remove-Variable alg, mult

	# display active miners
	if ($verbose -ne [eVerbose]::Minimal) {
		Out-Table ($ActiveMiners.Values |
			Sort-Object { [int]($_.State -as [eState]), [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } |
				Format-Table (Get-FormatActiveMiners ($verbose -eq [eVerbose]::Full)) -GroupBy State -Wrap)
	}

	if ($Config.ShowBalance) {
		Out-PoolBalance ($verbose -eq [eVerbose]::Minimal)
	}
	Out-Footer
	if ($DownloadMiners -and ($DownloadMiners.Length -gt 0 -or $DownloadMiners -is [PSCustomObject])) {
		Write-Host "Download miner(s): $(($DownloadMiners | Select-Object Name -Unique | ForEach-Object { $_.Name }) -Join `", `") ... " -ForegroundColor Yellow
	}
	if ($global:HasConfirm) {
		Write-Host "Please observe while the benchmarks are running ..." -ForegroundColor Red
	}
	if ($PSVersionTable.PSVersion -lt [version]::new(5,1)) {
		Write-Host "Please update PowerShell to version 5.1 (https://www.microsoft.com/en-us/download/details.aspx?id=54616)" -ForegroundColor Yellow
	}

	Remove-Variable verbose

	$switching = $Config.Switching -as [eSwitching]

	do {
		$FastLoop = $false

		$start = [Diagnostics.Stopwatch]::new()
		$start.Start()
		do {
			Start-Sleep -Milliseconds ([Config]::SmallTimeout)
			while ([Console]::KeyAvailable -eq $true) {
				[ConsoleKeyInfo] $key = [Console]::ReadKey($true)
				if (($key.Modifiers -match [ConsoleModifiers]::Alt -or $key.Modifiers -match [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::S) {
					$items = [enum]::GetValues([eSwitching])
					$index = [array]::IndexOf($items, $Config.Switching -as [eSwitching]) + 1
					$Config.Switching = if ($items.Length -eq $index) { $items[0] } else { $items[$index] }
					Remove-Variable index, items
					Write-Host "Switching mode changed to $($Config.Switching)." -ForegroundColor Green
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$FastLoop = $true
				}
				elseif ($key.Key -eq [ConsoleKey]::V) {
					$items = [enum]::GetValues([eVerbose])
					$index = [array]::IndexOf($items, $Config.Verbose -as [eVerbose]) + 1
					$Config.Verbose = if ($items.Length -eq $index) { $items[0] } else { $items[$index] }
					Remove-Variable index, items
					Write-Host "Verbose level changed to $($Config.Verbose)." -ForegroundColor Green
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$FastLoop = $true
				}
				elseif (($key.Modifiers -match [ConsoleModifiers]::Alt -or $key.Modifiers -match [ConsoleModifiers]::Control) -and
					($key.Key -eq [ConsoleKey]::C -or $key.Key -eq [ConsoleKey]::E -or $key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::X)) {
					$exit = $true
				}
				elseif (($key.Modifiers -match [ConsoleModifiers]::Alt -or $key.Modifiers -match [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::R) {
					New-Item ([IO.Path]::Combine([Config]::BinLocation, ".restart")) -ItemType Directory -Force | Out-Null
					$exit = $true
				}
				elseif ($Config.ShowBalance -and $key.Key -eq [ConsoleKey]::R) {
					$Config.ShowExchangeRate = !$Config.ShowExchangeRate;
					$FastLoop = $true
				}
				elseif ($key.Key -eq [ConsoleKey]::M -and !$global:HasConfirm) {
					Clear-OldMiners ($ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | ForEach-Object { $_.Miner.Name })
				}
				elseif ($key.Key -eq [ConsoleKey]::F -and !$global:HasConfirm) {
					if (Clear-FailedMiners ($ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Failed })) {
						$FastLoop = $true
					}
				}
				elseif ($key.Key -eq [ConsoleKey]::T -and !$global:HasConfirm -and [Config]::ActiveTypesInitial.Length -gt 1) {
					[Config]::ActiveTypes = Select-ActiveTypes ([Config]::ActiveTypesInitial)
					[Config]::ActiveTypesInitial | Where-Object { [Config]::ActiveTypes -notcontains $_ } | ForEach-Object {
						$type = $_
						$ActiveMiners.Values | Where-Object { $_.Miner.Type -eq $type -and $_.State -eq [eState]::Running } | ForEach-Object {
							$_.Stop($AllAlgos.RunAfter)
						}
						Remove-Variable type
					}
					# for normal loop
					$switching = $null
					$FastLoop = $true
				}
				elseif ($key.Key -eq [ConsoleKey]::Y -and $global:HasConfirm -eq $false -and $global:NeedConfirm -eq $true) {
					Write-Host "Thanks. " -ForegroundColor Green -NoNewline
					Write-Host "Please observe while the benchmarks are running ..." -ForegroundColor Red
					Start-Sleep -Milliseconds ([Config]::SmallTimeout * 2)
					$global:HasConfirm = $true
					$FastLoop = $true
				}
				elseif ($key.Key -eq [ConsoleKey]::P -and $global:HasConfirm -eq $false -and $global:NeedConfirm -eq $false -and [Config]::UseApiProxy -eq $false) {
					$global:AskPools = $true
					$FastLoop = $true
				}

				Remove-Variable key
			}
		} while ($start.Elapsed.TotalSeconds -lt $Config.CheckTimeout -and !$exit -and !$FastLoop)
		Remove-Variable start

		# if needed - exit
		if ($exit -eq $true) {
			Write-Host "Exiting ..." -ForegroundColor Green
			if ($global:API.Running) {
				Write-Host "Stoping API server ..." -ForegroundColor Green
				Stop-ApiServer
			}
			$ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | ForEach-Object {
				$_.Stop($AllAlgos.RunAfter)
			}
			exit
		}

		if (!$FastLoop) {
			# read speed while run main loop timeout
			if ($ActiveMiners.Values -and $ActiveMiners.Values.Length -gt 0) {
				Get-Speed $ActiveMiners.Values
			}
			# check miners work propertly
			$ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
				$prevState = $_.State
				if ($_.Check($AllAlgos.RunAfter) -eq [eState]::Failed -and $prevState -ne [eState]::Failed) {
					# miner failed - run next
					if ($_.Action -eq [eAction]::Benchmark) {
						$speed = $Statistics.SetValue($_.Miner.GetFilename(), $_.Miner.GetKey(), -1)
						Remove-Variable speed
					}
					$FastLoop = $true
				}
				# benchmark time reached - exit from loop
				elseif ($_.Action -eq [eAction]::Benchmark -and $_.State -ne [eState]::Failed) {
					$speed = $_.GetSpeed($false)
					if (($_.CurrentTime.Elapsed.TotalSeconds -ge $_.Miner.BenchmarkSeconds -and $speed -gt 0) -or
						($_.CurrentTime.Elapsed.TotalSeconds -ge ($_.Miner.BenchmarkSeconds * 2) -and $speed -eq 0)) {
						$FastLoop = $true
					}
					Remove-Variable speed
				}
				Remove-Variable prevState
			}
		}
		if ($global:API.Running) {
			$global:API.MinersRunning = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersWeb) | ConvertTo-Html -Fragment
			$global:API.ActiveMiners = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running } | Select-Object (Get-FormatActiveMinersApi)
			$global:API.Info = $Summary | Select-Object ($Summary.Columns()) | ConvertTo-Html -Fragment
			$global:API.Status = $Summary | Select-Object ($Summary.ColumnsApi())
		}
	} while ($Config.LoopTimeout -gt $Summary.LoopTime.Elapsed.TotalSeconds -and !$FastLoop)

	# if timeout reached or askpools or bench or change switching mode - normal loop
	if ($Config.LoopTimeout -le $Summary.LoopTime.Elapsed.TotalSeconds -or $switching -ne $Config.Switching -or
		$global:AskPools -eq $true -or ($global:HasConfirm -eq $true -and $global:NeedConfirm -eq $true)) {
		$FastLoop = $false
	}

	if (!$FastLoop) {
		if ($Summary.RateTime.IsRunning -eq $false -or $Summary.RateTime.Elapsed.TotalSeconds -ge [Config]::RateTimeout.TotalSeconds) {
			Clear-OldMinerStats $AllMiners $Statistics "180 days"
		}
		$global:NeedConfirm = $false
		Remove-Variable AllPools, AllMiners
		[GC]::Collect()
		$Summary.Loop++
	}
}
