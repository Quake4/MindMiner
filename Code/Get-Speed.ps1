<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\MinerProcess.ps1

function Get-TCPCommand([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Server, [Parameter(Mandatory)][int] $Port,
	[string] $Command, [Parameter(Mandatory)][scriptblock] $Script, [bool] $ReadAll) {
	try {
		$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
		$Stream = $Client.GetStream()
		$Stream.ReadTimeout = $Stream.WriteTimeout = $MinerProcess.Config.CheckTimeout * 1000;
		$Writer = [IO.StreamWriter]::new($Stream)
		$Reader = [IO.StreamReader]::new($Stream)

		if (![string]::IsNullOrWhiteSpace($Command)) {
			# if ($MinerProcess.Miner.API.ToLower() -eq "dredge") { $Writer.Write($Command) } else { $Writer.WriteLine($Command) };
			$Writer.WriteLine($Command)
			$Writer.Flush()
		}
		if ($ReadAll) { $result = $Reader.ReadToEnd() } else { $result = $Reader.ReadLine() }
		if (![string]::IsNullOrWhiteSpace($result)) {
			$Script.Invoke($result)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
		Remove-Variable result
	}
	catch {
		Write-Host "Get-Speed $($MinerProcess.Miner.Name) error: $_" -ForegroundColor Red
		$MinerProcess.ErrorAnswer++
	}
	finally {
		if ($Reader) { $Reader.Dispose(); $Reader = $null }
		if ($Writer) { $Writer.Dispose(); $Writer = $null }
		if ($Stream) { $Stream.Dispose(); $Stream = $null }
		if ($Client) { $Client.Dispose(); $Client = $null }
	}
}

function Get-Http ([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Url, [Parameter(Mandatory)][scriptblock] $Script) {
	try {
		$Request = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec ($MinerProcess.Config.CheckTimeout)
		if ($Request -and $Request.StatusCode -eq 200 -and ![string]::IsNullOrWhiteSpace($Request.Content)) {
			$Script.Invoke($Request.Content)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
	}
	catch {
		Write-Host "Get-Speed $($MinerProcess.Miner.Name) error: $_" -ForegroundColor Red
		$MinerProcess.ErrorAnswer++
	}
	finally {
		if ($Request -is [IDisposable]) { $Request.Dispose(); $Request = $null; }
	}
}

function Get-HttpAsJson ([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Url, [Parameter(Mandatory)][scriptblock] $ScriptInt) {
	Get-Http $MinerProcess $Url {
		Param([string] $result)
		$resjson = $result | ConvertFrom-Json
		if ($resjson) {
			$ScriptInt.Invoke($resjson)
		}
		else {
			$MinerProcess.ErrorAnswer++
		}
	}
}

function Get-Speed([Parameter(Mandatory = $true)] [MinerProcess[]] $MinerProcess) {
	# read speed only Running and time reach bench / 2
	$MinerProcess | Where-Object { $_.State -eq [eState]::Running -and 
		$_.CurrentTime.Elapsed.TotalSeconds -ge [Math]::Max($_.Miner.BenchmarkSeconds / 2, $_.Miner.BenchmarkSeconds - $_.Config.CheckTimeout * 2) } | ForEach-Object {
		$MP = $_
		$Server = "127.0.0.1"
		$Port = $_.Miner.Port
		$AVESpeed = "{0} sec" -f [Math]::Min([Convert]::ToInt32($MP.CurrentTime.Elapsed.TotalSeconds), $MP.Config.AverageCurrentHashSpeed)

		switch ($MP.Miner.API.ToLower()) {
			"cpuminer" {
				@("summary", "threads") | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						$key = [string]::Empty
						if ($_ -eq "threads") {
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("CPU=")) {
									$key = $_.Replace("CPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$split = $_.Split(@("="))
									Set-SpeedStr $key $split[1] ($split[0].Replace("H/s", [string]::Empty).Replace("HS", [string]::Empty))
									$key = [string]::Empty
									Remove-Variable split
								}
							}
						}
						else {
							$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::Equals($_, "KHS", [StringComparison]::InvariantCultureIgnoreCase)) {
									$key = $_
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$key = [string]::Empty
									Set-SpeedStr $key $_ "K"
								}
							}
						}
						Remove-Variable key
					}
				}
			}

			{ $_ -eq "ccminer" -or $_ -eq "ccminer_woe" -or $_ -eq "dredge" } {
				$commands = if ($_ -eq "ccminer_woe") { @("summary") } else { @("summary", "threads"<# , "pool" #>) }
				$commands | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						$key = [string]::Empty
						<#
						if ($_ -eq "pool") {
							Write-Host "pool: $result"
							# pool: POOL=europe.hub.miningpoolhub.com:20510;ALGO=neoscrypt;URL=stratum+tcp://europe.hub.miningpoolhub.com:20510;USER=1.Home;SOLV=0;ACC=0;REJ=0;STALE=0;H=1997109;JOB=287d;DIFF=2048.000000;BEST=0.000000;N2SZ=4;N2=0x01000000;PING=0;DISCO=0;WAIT=0;UPTIME=0;LAST=0|
						}
						#>
						if ($_ -eq "threads" -and $MP.Miner.API.ToLower() -ne "ccminer_woe") {
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("GPU=")) {
									$key = $_.Replace("GPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("KHS=")) {
									Set-SpeedStr $key ($_.Replace("KHS=", [string]::Empty)) "K"
									$key = [string]::Empty
								}
							}
						}
						elseif ($_ -eq "summary") {
							$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::Equals($_, "KHS", [StringComparison]::InvariantCultureIgnoreCase)) {
									$key = $_
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$key = [string]::Empty
									Set-SpeedStr $key $_ "K"
								}
							}
						}
						Remove-Variable key
					}
				}
			}

			"ewbf" {
				Get-TCPCommand $MP $Server $Port "{`"id`":1, `"method`":`"getstat`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$resjson.result | ForEach-Object {
							Set-SpeedStr ($_.gpuid) ($_.speed_sps) ([string]::Empty)
						}
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			{ $_ -eq "nheq" -or $_ -eq "nheq_verus" } {
				Get-TCPCommand $MP $Server $Port "status" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$unit = [string]::Empty
						$value = $resjson.result.speed_sps
						if ($MP.Miner.API.ToLower() -eq "nheq_verus" ) {
							$unit = "M"
							$value = $resjson.result.speed_ips
						}
						Set-SpeedStr ([string]::Empty) $value $unit
						Remove-Variable value, unit
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			{ $_ -eq "sgminer" -or $_ -eq "teamred"} {
				# https://github.com/ckolivas/cgminer/blob/master/API-README
				Get-TCPCommand $MP $Server $Port "{`"command`":`"summary+devs`"}" {
					Param([string] $result)
					# fix error symbol at end
					while ($result[$result.Length - 1] -eq 0) {
						$result = $result.substring(0, $result.Length - 1)
					}
					$key = "KHS 5s"
					if ($MP.Miner.API.ToLower() -eq "teamred" ) { $key = "KHS 30s" }
					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						if ($resjson.devs[0].DEVS) {
							$resjson.devs[0].DEVS | ForEach-Object {
								Set-SpeedStr ($_.GPU) ($_.$key) "K"
							}
						}
						Set-SpeedStr ([string]::Empty) ($resjson.summary[0].SUMMARY.$key) "K"
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			{ $_ -eq "claymore" -or $_ -eq "claymoredual" } {
				Get-TCPCommand $MP $Server $Port "{`"id`":0,`"jsonrpc`":`"2.0`",`"method`":`"miner_getstat1`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$measure = [string]::Empty
						if ($resjson.result[0].Contains("ETH") -or $resjson.result[0].Contains("NS") -or $resjson.result[0].Contains("ethminer") -or
							($resjson.result[0].Contains("PM") -and !$resjson.result[0].Contains("3.0c"))) { $measure = "K" }
						if (![string]::IsNullOrWhiteSpace($resjson.result[2])) {
							$item = $resjson.result[2].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 1
							Set-SpeedStr ([string]::Empty) $item $measure
							Remove-Variable item
						}
						if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
							$items = $resjson.result[3].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
							for ($i = 0; $i -lt $items.Length; $i++) {
								Set-SpeedStr "$i" ($items[$i]) $measure
							}
							Remove-Variable items
						}
						if ($MP.Miner.API.ToLower() -eq "claymoredual") {
							if (![string]::IsNullOrWhiteSpace($resjson.result[4])) {
								$item = $resjson.result[4].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 1
								Set-SpeedDual ([string]::Empty) $item $measure
								Remove-Variable item
							}
							if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
								$items = $resjson.result[5].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
								for ($i = 0; $i -lt $items.Length; $i++) {
									Set-SpeedDual "$i" ($items[$i]) $measure
								}
								Remove-Variable items
							}
						}
						Remove-Variable measure
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"dstm" {
				Get-TCPCommand $MP $Server $Port "{`"id`":1, `"method`":`"getstat`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$resjson.result | ForEach-Object {
							Set-SpeedStr ($_.gpu_id) ($_.sol_ps) ([string]::Empty)
						}
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"cast" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$resjson.devices | ForEach-Object {
						$speed = [MultipleUnit]::ToValueInvariant($_.hash_rate, [string]::Empty)
						Set-SpeedVal ($_.device) ($speed / 1000)
					}
					$speed = [MultipleUnit]::ToValueInvariant($resjson.total_hash_rate, [string]::Empty)
					Set-SpeedVal ([string]::Empty) ($speed / 1000)
					Remove-Variable speed
				}
			}
			
			"bminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/status" {
					Param([PSCustomObject] $resjson)

					$resjson.miners | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						Set-SpeedStr $_ ($resjson.miners."$_".solver.solution_rate) ([string]::Empty)
					}
				}
			}

			"bminerdual" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status/solver" {
					Param([PSCustomObject] $resjson)

					$resjson.devices | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$id = "$_"
						$resjson.devices."$_".solvers | ForEach-Object {
							if ($_.algorithm -match "ethash") {
								Set-SpeedStr $id ($_.speed_info.hash_rate) ([string]::Empty)
							}
							else {
								Set-SpeedDual "$i" ($_.speed_info.hash_rate) ([string]::Empty)
							}
						}
						Remove-Variable id
					}
				}
			}

			"jce" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					for ($i = 0; $i -lt $resjson.hashrate.thread_all.Length; $i++) {
						Set-SpeedVal "$i" $resjson.hashrate.thread_all[$i]
					}
					Set-SpeedVal ([string]::Empty) $resjson.hashrate.total
				}
			}

			"xmrig" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					for ($i = 0; $i -lt $resjson.hashrate.threads.Length; $i++) {
						$speed = if ($resjson.hashrate.threads[$i][1] -gt 0) { $resjson.hashrate.threads[$i][1] } else { $resjson.hashrate.threads[$i][0] }
						Set-SpeedVal "$i" $speed
					}
					$speed = if ($resjson.hashrate.total[1] -gt 0) { $resjson.hashrate.total[1] } else { $resjson.hashrate.total[0] }
					Set-SpeedVal ([string]::Empty) $speed
					Remove-Variable speed
				}
			}

			"xmr-stak" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api.json" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					for ($i = 0; $i -lt $resjson.hashrate.threads.Length; $i++) {
						$speed = if ($resjson.hashrate.threads[$i][1] -gt 0) { $resjson.hashrate.threads[$i][1] } else { $resjson.hashrate.threads[$i][0] }
						Set-SpeedVal "$i" $speed
					}
					$speed = if ($resjson.hashrate.total[1] -gt 0) { $resjson.hashrate.total[1] } else { $resjson.hashrate.total[0] }
					Set-SpeedVal ([string]::Empty) $speed
					Remove-Variable speed
				}
			}

			"lol" {
				Get-TCPCommand $MP $Server $Port -ReadAll $true -Script {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$resjson | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
							$key = "$_"
							if ($key.StartsWith("GPU")) {
								Set-SpeedStr $key ($resjson."$_"."Speed(30s)") ([string]::Empty)
							}
							elseif ($key -eq "TotalSpeed(30s)") {
								Set-SpeedStr ([string]::Empty) ($resjson.$key) ([string]::Empty)
							}
						}
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"lolnew" {
				Get-HttpAsJson $MP "http://$Server`:$Port/summary" {
					Param([PSCustomObject] $resjson)

					$resjson.GPUs | ForEach-Object {
						Set-SpeedStr ($_.Index) ($_.Performance) ([string]::Empty)
					}
					Set-SpeedStr ([string]::Empty) ($resjson.Session.Performance_Summary) ([string]::Empty)
				}
			}

			"gminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status" {
					Param([PSCustomObject] $resjson)

					$resjson.miner.devices | ForEach-Object {
						Set-SpeedStr ($_.id) ($_.hashrate) ([string]::Empty)
					}
					Set-SpeedStr ([string]::Empty) ($resjson.miner.total_hashrate) ([string]::Empty)
				}
			}

			"zjazz_cuckoo" {
				@("summary", "threads"<# , "pool" #>) | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						$key = [string]::Empty
						<#
						if ($_ -eq "pool") {
							Write-Host "pool: $result"
							# pool: POOL=europe.hub.miningpoolhub.com:20510;ALGO=neoscrypt;URL=stratum+tcp://europe.hub.miningpoolhub.com:20510;USER=1.Home;SOLV=0;ACC=0;REJ=0;STALE=0;H=1997109;JOB=287d;DIFF=2048.000000;BEST=0.000000;N2SZ=4;N2=0x01000000;PING=0;DISCO=0;WAIT=0;UPTIME=0;LAST=0|
						}
						#>
						if ($_ -eq "threads") {
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("GPU=")) {
									$key = $_.Replace("GPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("KHS=")) {
									Set-SpeedStrMultiplier $key ($_.Replace("KHS=", [string]::Empty)) 0.001
									$key = [string]::Empty
								}
							}
						}
						elseif ($_ -eq "summary") {
							$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::Equals($_, "KHS", [StringComparison]::InvariantCultureIgnoreCase)) {
									$key = $_
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$key = [string]::Empty
									Set-SpeedStrMultiplier $key $_ 0.001
								}
							}
						}
						Remove-Variable key
					}
				}
			}
			
			Default {
				throw [Exception]::new("Get-Speed: Uknown miner $($MP.Miner.API)!")
			}
		}
		Remove-Variable AVESpeed, Port, Server, MP
	}
}

function Set-SpeedStr ([string] $Key, [string] $Value, [string] $Unit) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, $Unit)
	Set-SpeedVal $Key $speed
	Remove-Variable speed
}

function Set-SpeedVal ([string] $Key, [decimal] $Value) {
	if ($Value -lt [Config]::MinSpeed) {
		$Value = 0
	}
	$MP.SetSpeed($Key, $Value, $AVESpeed)
}

function Set-SpeedStrMultiplier ([string] $Key, [string] $Value, [decimal] $Multiplier) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, [string]::Empty) * $Multiplier
	Set-SpeedVal $Key $speed
	Remove-Variable speed
}

function Set-SpeedDual ([string] $Key, [string] $Value, [string] $Unit) {
	[decimal] $speed = [MultipleUnit]::ToValueInvariant($Value, $Unit)
	if ($Value -lt [Config]::MinSpeed) {
		$Value = 0
	}
	$MP.SetSpeedDual($Key, $speed, $AVESpeed)
	Remove-Variable speed
}