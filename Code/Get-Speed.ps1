<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\MinerProcess.ps1

function Get-TCPCommand([Parameter(Mandatory)][MinerProcess] $MinerProcess, [Parameter(Mandatory)][string] $Server, [Parameter(Mandatory)][int] $Port,
	[Parameter(Mandatory)][string] $Command, [Parameter(Mandatory)][scriptblock] $Script) {
	try {
		$Client =[Net.Sockets.TcpClient]::new($Server, $Port)
		$Stream = $Client.GetStream()
		$Writer = [IO.StreamWriter]::new($Stream)
		$Reader = [IO.StreamReader]::new($Stream)

		if ($MinerProcess.Miner.API.ToLower() -eq "dredge") { $Writer.Write($Command) } else { $Writer.WriteLine($Command) };
		$Writer.Flush()
		$result = $Reader.ReadLine()
		if (![string]::IsNullOrWhiteSpace($result)) {
			$Script.Invoke($result)
			$MinerProcess.ErrorAnswer = 0
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
		try {
			$Request = Invoke-WebRequest $Url -TimeoutSec ($MinerProcess.Config.CheckTimeout)
		}
		catch {
			if ($Request -is [IDisposable]) { $Request.Dispose(); $Request = $null; }
			$Request = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec ($MinerProcess.Config.CheckTimeout)
		}
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
			$MP.ErrorAnswer++
		}
	}
}

function Get-Speed() {
	param(
		[Parameter(Mandatory = $true)]
		[MinerProcess[]] $MinerProcess
	)

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
						[decimal] $speed = 0 # if var not initialized - this outputed to console
						if ($_ -eq "threads") {
							$result.Split(@("|",";"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
								if ([string]::IsNullOrWhiteSpace($key) -and $_.StartsWith("CPU=")) {
									$key = $_.Replace("CPU=", [string]::Empty)
								}
								elseif (![string]::IsNullOrWhiteSpace($key)) {
									$split = $_.Split(@("="))
									$speed = [MultipleUnit]::ToValueInvariant($split[1], $split[0].Replace("H/s", [string]::Empty).Replace("HS", [string]::Empty))
									$MP.SetSpeed($key, $speed, $AVESpeed)
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
									$speed = [MultipleUnit]::ToValueInvariant($_, "K")
									$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
									$key = [string]::Empty
								}
							}
						}
						Remove-Variable speed, key
					}
				}
			}

			{ $_ -eq "ccminer" -or $_ -eq "ccminer_woe" -or $_ -eq "dredge" } {
				$commands = if ($_ -eq "ccminer_woe") { @("summary") } else { @("summary", "threads"<# , "pool" #>) }
				$commands | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						$key = [string]::Empty
						[decimal] $speed = 0 # if var not initialized - this outputed to console
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
									$speed = [MultipleUnit]::ToValueInvariant($_.Replace("KHS=", [string]::Empty), "K")
									$MP.SetSpeed($key, $speed, $AVESpeed)
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
									$speed = [MultipleUnit]::ToValueInvariant($_, "K")
									$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
									$key = [string]::Empty
								}
							}
						}
						Remove-Variable speed, key
					}
				}
			}

			"trex" {
				Get-TCPCommand $MP $Server $Port "summary" {
					Param([string] $result)

					$key = [string]::Empty
					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$result.Split(@('|',';','='), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
						if ([string]::Equals($_, "KHS", [StringComparison]::InvariantCultureIgnoreCase)) {
							$key = $_
						}
						elseif (![string]::IsNullOrWhiteSpace($key)) {
							$speed = [MultipleUnit]::ToValueInvariant($_, [string]::Empty)
							$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
							$key = [string]::Empty
						}
					}
					Remove-Variable speed, key
				}
			}

			"ewbf" {
				Get-TCPCommand $MP $Server $Port "{`"id`":1, `"method`":`"getstat`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						[decimal] $speed = 0 # if var not initialized - this outputed to console
						$resjson.result | ForEach-Object {
							$speed = [MultipleUnit]::ToValueInvariant($_.speed_sps, [string]::Empty)
							$MP.SetSpeed($_.gpuid, $speed, $AVESpeed)
						}
						Remove-Variable speed
						$MP.ErrorAnswer = 0
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"nheq" {
				Get-TCPCommand $MP $Server $Port "status" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						$speed = [MultipleUnit]::ToValueInvariant($resjson.result.speed_sps, [string]::Empty)
						$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
						Remove-Variable speed
						$MP.ErrorAnswer = 0
					}
					else {
						$MP.ErrorAnswer++
					}
					Remove-Variable resjson
				}
			}

			"sgminer" {
				# https://github.com/ckolivas/cgminer/blob/master/API-README
				@("{`"command`":`"summary`"}", "{`"command`":`"devs`"}") | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)
						# fix error symbol at end
						while ($result[$result.Length - 1] -eq 0) {
							$result = $result.substring(0, $result.Length - 1)
						}
						$resjson = $result | ConvertFrom-Json
						if ($resjson) {
							[decimal] $speed = 0 # if var not initialized - this outputed to console
							if ($resjson.DEVS) {
								$resjson.DEVS | ForEach-Object {
									$speed = [MultipleUnit]::ToValueInvariant($_."KHS 5s", "K")
									$MP.SetSpeed($_.GPU, $speed, $AVESpeed)
								}
							}
							else {
								$speed = [MultipleUnit]::ToValueInvariant($resjson.SUMMARY."KHS 5s", "K")
								$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
							}
							Remove-Variable speed
							$MP.ErrorAnswer = 0
						}
						else {
							$MP.ErrorAnswer++
						}
						Remove-Variable resjson
					}
				}
			}

			{ $_ -eq "claymore" -or $_ -eq "claymoredual" } {
				@("{`"id`":0,`"jsonrpc`":`"2.0`",`"method`":`"miner_getstat1`"}") | ForEach-Object {
					Get-TCPCommand $MP $Server $Port $_ {
						Param([string] $result)

						$resjson = $result | ConvertFrom-Json
						if ($resjson) {
							[decimal] $speed = 0 # if var not initialized - this outputed to console
							$measure = [string]::Empty
							if ($resjson.result[0].Contains("ETH") -or $resjson.result[0].Contains("NS")) { $measure = "K" }
							if (![string]::IsNullOrWhiteSpace($resjson.result[2])) {
								$item = $resjson.result[2].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 1
								$speed = [MultipleUnit]::ToValueInvariant($item, $measure)
								$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
								Remove-Variable item
							}
							if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
								$items = $resjson.result[3].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
								for ($i = 0; $i -lt $items.Length; $i++) {
									$speed = [MultipleUnit]::ToValueInvariant($items[$i], $measure)
									$MP.SetSpeed($i, $speed, $AVESpeed)
								}
								Remove-Variable items
							}
							if ($MP.Miner.API.ToLower() -eq "claymoredual") {
								if (![string]::IsNullOrWhiteSpace($resjson.result[4])) {
									$item = $resjson.result[4].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -First 1
									$speed = [MultipleUnit]::ToValueInvariant($item, $measure)
									$MP.SetSpeedDual([string]::Empty, $speed, $AVESpeed)
									Remove-Variable item
								}
								if (![string]::IsNullOrWhiteSpace($resjson.result[3])) {
									$items = $resjson.result[5].Split(@(';'), [StringSplitOptions]::RemoveEmptyEntries)
									for ($i = 0; $i -lt $items.Length; $i++) {
										$speed = [MultipleUnit]::ToValueInvariant($items[$i], $measure)
										$MP.SetSpeedDual($i, $speed, $AVESpeed)
									}
									Remove-Variable items
								}
							}
							Remove-Variable measure, speed
							$MP.ErrorAnswer = 0
						}
						else {
							$MP.ErrorAnswer++
						}
						Remove-Variable resjson
					}
				}
			}

			"dstm" {
				Get-TCPCommand $MP $Server $Port "{`"id`":1, `"method`":`"getstat`"}" {
					Param([string] $result)

					$resjson = $result | ConvertFrom-Json
					if ($resjson) {
						[decimal] $speed = 0 # if var not initialized - this outputed to console
						$resjson.result | ForEach-Object {
							$speed = [MultipleUnit]::ToValueInvariant($_.sol_ps, [string]::Empty)
							$MP.SetSpeed($_.gpu_id, $speed, $AVESpeed)
						}
						Remove-Variable speed
						$MP.ErrorAnswer = 0
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
						$MP.SetSpeed($_.device, $speed / 1000, $AVESpeed)
					}
					$speed = [MultipleUnit]::ToValueInvariant($resjson.total_hash_rate, [string]::Empty)
					$MP.SetSpeed([string]::Empty, $speed / 1000, $AVESpeed)
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}
			
			"bminer" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/status" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$resjson.miners | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$speed = [MultipleUnit]::ToValueInvariant($resjson.miners."$_".solver.solution_rate, [string]::Empty)
						$MP.SetSpeed($_, $speed, $AVESpeed)
					}
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}

			"bminerdual" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api/v1/status/solver" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$resjson.devices | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$id = "$_"
						$resjson.devices."$_".solvers | ForEach-Object {
							if ($_.algorithm -match "ethash") {
								$speed = [MultipleUnit]::ToValueInvariant($_.speed_info.hash_rate, [string]::Empty)
								$MP.SetSpeed($id, $speed, $AVESpeed)
							}
							else {
								$speed = [MultipleUnit]::ToValueInvariant($_.speed_info.hash_rate, [string]::Empty)
								$MP.SetSpeedDual($id, $speed, $AVESpeed)
							}
						}
						Remove-Variable id
					}
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}

			"jce" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					for ($i = 0; $i -lt $resjson.hashrate.thread_all.Length; $i++) {
						$MP.SetSpeed("$i", $resjson.hashrate.thread_all[$i], $AVESpeed)
					}
					$MP.SetSpeed([string]::Empty, $resjson.hashrate.total, $AVESpeed)
					$MP.ErrorAnswer = 0
				}
			}

			"xmrig" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					for ($i = 0; $i -lt $resjson.hashrate.threads.Length; $i++) {
						$speed = if ($resjson.hashrate.threads[$i][1] -gt 0) { $resjson.hashrate.threads[$i][1] } else { $resjson.hashrate.threads[$i][0] }
						$MP.SetSpeed("$i", $speed, $AVESpeed)
					}
					$speed = if ($resjson.hashrate.total[1] -gt 0) { $resjson.hashrate.total[1] } else { $resjson.hashrate.total[0] }
					$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}

			"xmr-stak" {
				Get-HttpAsJson $MP "http://$Server`:$Port/api.json" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					for ($i = 0; $i -lt $resjson.hashrate.threads.Length; $i++) {
						$speed = if ($resjson.hashrate.threads[$i][1] -gt 0) { $resjson.hashrate.threads[$i][1] } else { $resjson.hashrate.threads[$i][0] }
						$MP.SetSpeed("$i", $speed, $AVESpeed)
					}
					$speed = if ($resjson.hashrate.total[1] -gt 0) { $resjson.hashrate.total[1] } else { $resjson.hashrate.total[0] }
					$MP.SetSpeed([string]::Empty, $speed, $AVESpeed)
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}

			"lol" {
				Get-HttpAsJson $MP "http://$Server`:$Port" {
					Param([PSCustomObject] $resjson)

					[decimal] $speed = 0 # if var not initialized - this outputed to console
					$resjson | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$key = "$_"
						if ($key.StartsWith("GPU")) {
							$speed = [MultipleUnit]::ToValueInvariant($resjson."$_"."Speed(60s)", [string]::Empty)
							$MP.SetSpeed($key, $speed, $AVESpeed)
						}
					}
					Remove-Variable speed
					$MP.ErrorAnswer = 0
				}
			}
			
			Default {
				throw [Exception]::new("Get-Speed: Uknown miner $($MP.Miner.API)!")
			}
		}
		Remove-Variable AVESpeed, Port, Server, MP
	}
}