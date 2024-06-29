<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1
. .\Code\Config.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1

enum eState {
	Stopped
	Failed
	NoHash
	Running
}

enum eAction {
	Normal
	Benchmark
	Service
	Fee
}

class MinerProcess {
	[string] $State
	[MinerInfo] $Miner
	[Diagnostics.Stopwatch] $TotalTime
	[Diagnostics.Stopwatch] $CurrentTime
	[int] $Run
	[Config] $Config
	[int] $ErrorAnswer
	[eAction] $Action
	hidden [StatGroup] $Speed
	hidden [StatGroup] $SpeedDual
	hidden [StatInfo] $Power
	[Shares] $Shares # add in get-speed
	[Shares] $SharesDual # add in get-speed
	hidden [decimal] $SharesCache
	hidden [decimal] $SharesCacheDual
	hidden [hashtable] $FlatResult
	hidden [int] $NoHashCount
	hidden [Diagnostics.Process] $Process

	MinerProcess([MinerInfo] $miner, [Config] $config) {
		$this.Miner = [MinerInfo]($miner | ConvertTo-Json | ConvertFrom-Json)
		$this.Config = $config
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.CurrentTime = [Diagnostics.Stopwatch]::new()
		$this.Speed = [StatGroup]::new()
		$this.SpeedDual = [StatGroup]::new()
		$this.Shares = [Shares]::new()
		$this.SharesDual = [Shares]::new()
	}

	[void] Start([bool] $nbench, $runbefore) {
		$act = if ($nbench) { [eAction]::Service } else { [eAction]::Normal }
		$this.StartInt($act, $runbefore)
	}

	[void] Benchmark([bool] $nbench, $runbefore) {
		$act = if ($nbench) { [eAction]::Fee } else { [eAction]::Benchmark }
		$this.StartInt($act, $runbefore)
	}

	[bool] CanFee() {
		return $this.Miner.Arguments.IndexOf($this.Config.Wallet.BTC) -gt 0
	}

	[void] SetSpeed([string] $key, [decimal] $speed, [string] $interval) {
		if (($speed -ge 0 -and $this.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $this.Action -ne [eAction]::Normal)) {
			$spd = $this.Speed.SetValue($key, $speed * (100 - $this.Miner.Fee) / 100, $interval)
			Remove-Variable spd
		}
	}

	[void] SetSpeedDual([string] $key, [decimal] $speed, [string] $interval) {
		if (($speed -ge 0 -and $this.Action -eq [eAction]::Normal) -or ($speed -gt 0 -and $this.Action -ne [eAction]::Normal)) {
			$spd = $this.SpeedDual.SetValue($key, $speed, $interval)
			Remove-Variable spd
		}
	}

	[decimal] GetSpeed([bool] $dual = $false) {
		if ($this.FlatResult) {
			if ($dual) { return $this.FlatResult["SpeedDual"] } else { return $this.FlatResult["Speed"] }
		}
		$spd = $this.Speed;
		$sharestime = $this.Miner.BenchmarkSeconds * 5;
		$sharesvalue = $this.Shares.Get($sharestime);
		if ($dual) {
			$spd = $this.SpeedDual;
			$sharesvalue = $this.SharesDual.Get($sharestime);
			if ($this.State -eq [eState]::Running -and ($this.CurrentTime.Elapsed.TotalSeconds -gt $sharestime -or $this.SharesDual.HasValue($sharestime, 5) -or $sharesvalue -ne $this.SharesCacheDual)) {
				$this.SharesCacheDual = $sharesvalue;
			}
		}
		elseif ($this.State -eq [eState]::Running -and ($this.CurrentTime.Elapsed.TotalSeconds -gt $sharestime -or $this.Shares.HasValue($sharestime, 5) -or $sharesvalue -ne $this.SharesCache)) {
			$this.SharesCache = $sharesvalue;
		}
		Remove-Variable sharestime
		if ($dual) { $sharesvalue = $this.SharesCacheDual } else { $sharesvalue = $this.SharesCache }
		# total speed by share
		[decimal] $result = $spd.GetValue()
		# sum speed by benchmark
		[decimal] $sum = 0
		$spd.Values.GetEnumerator() | Where-Object { $_.Key -ne [string]::Empty } | ForEach-Object {
			$sum += $_.Value.Value
		}
		# if bench - need fast evaluation - get theoretical speed
		if ($sum -gt 0 -and $this.Action -eq [eAction]::Benchmark) {
			return $sum
		}
		# if both - average
		if ($result -gt 0 -and $sum -gt 0) {
			return ($result + $sum) / 2 * $sharesvalue
		}
		if ($result -gt 0) {
			return $result * $sharesvalue
		}
		return $sum * $sharesvalue
	}

	[void] SetPower([decimal] $power) {
		if ($this.Power) {
			$tmp = $this.Power.SetValue($power, "$($this.Config.AverageCurrentHashSpeed) sec")
			Remove-Variable tmp
		}
		else {
			$this.Power = [StatInfo]::new($power)
		}
	}

	[decimal] GetPower() {
		return $this.Power.Value;
	}
	
	hidden [void] StartInt([eAction] $action, $runbefore) {
		if ($this.Process) { return }
		if ($runbefore) {
			if ($runbefore -is [string] -and ![string]::IsNullOrWhiteSpace($runbefore)) {
				$this.Miner.RunBefore = $runbefore
			}
			elseif (![string]::IsNullOrWhiteSpace($runbefore."$($this.Miner.Algorithm)")) {
				$this.Miner.RunBefore = $runbefore."$($this.Miner.Algorithm)"
			}
			elseif ($runbefore."$($this.Miner.Type)" -is [string] -and ![string]::IsNullOrWhiteSpace($runbefore."$($this.Miner.Type)")) {
				$this.Miner.RunBefore = $runbefore."$($this.Miner.Type)"
			}
			elseif (![string]::IsNullOrWhiteSpace($runbefore."$($this.Miner.Type)"."$($this.Miner.Algorithm)")) {
				$this.Miner.RunBefore = $runbefore."$($this.Miner.Type)"."$($this.Miner.Algorithm)"
			}
		}
		$this.SharesCache = 1
		$this.Action = $action
		$this.Run += 1
		$this.State = [eState]::Running
		$this.TotalTime.Start()
		$this.CurrentTime.Restart()
		$this.Speed = [StatGroup]::new()
		$this.SpeedDual = [StatGroup]::new()
		$this.Shares.Clear()
		$this.FlatResult = $null
		$argmnts = $this.Miner.Arguments
		if ($action -ne [eAction]::Normal -and $action -ne [eAction]::Benchmark) {
			$this.Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
			Where-Object { ![string]::IsNullOrWhiteSpace($this.Config.Wallet.$_) } | ForEach-Object {
				if ($argmnts.Contains(($this.Config.Wallet.$_))) {
					$argmnts = $argmnts.Replace($this.Config.Wallet.$_,
						$(if ($action -eq [eAction]::Service) { if ("$_" -match "NiceHash" -and ![string]::IsNullOrWhiteSpace($this.Config.Service.NiceHash)) { $this.Config.Service.NiceHash } else { $this.Config.Service.BTC } } else { [MinerProcess]::adr }))
					if (@("BTC", "NiceHash", "NiceHashNew") -notcontains "$_") {
						$sign = [regex]::new("(^|,|\s)(?!c=BTC(,|\s|$))c=(?<sign>([A-Z0-9]+))(,|\s|$)")
						do {
							$match = $sign.Match($argmnts)
							if ($match.Success) {
								$argmnts = $argmnts.Remove($match.Groups["sign"].Index, $match.Groups["sign"].Length)
								$argmnts = $argmnts.Insert($match.Groups["sign"].Index, "BTC")
							}
						} while ($match.Success)
						Remove-Variable match, sign
					}
				}
			}
			if (![string]::IsNullOrWhiteSpace($this.Config.Login)) {
				$argmnts = $argmnts.Replace($this.Config.Login + ".", $(if ($action -eq [eAction]::Service -and ![string]::IsNullOrWhiteSpace($this.Config.Service.Login)) { $this.Config.Service.Login } else { [MinerProcess]::lgn }) + ".")
			}
			$argmnts = $argmnts -replace ",m=solo" -replace "%2Cm=solo" -replace "%2Cm%3Dsolo"
			if ($argmnts.Contains("party") -and $action -ne [eAction]::Service) {
				$sign = [regex]::new("m(=|%3(d|D))party\.(\w+,|\w+%2(c|C)|\w+$)")
				$match = $sign.Match($argmnts)
				if ($match.Success) {
					$argmnts = $argmnts.Remove($match.Index, $match.Length)
				}
				Remove-Variable match, sign
			}
		}
		$this.RunCmd($this.Miner.RunBefore)
		$Dir = Split-Path -Path ([IO.Path]::Combine([Config]::BinLocation, $this.Miner.Path))
		#fix xmr-stack
		Remove-Item "$Dir\pools.txt" -Force -ErrorAction SilentlyContinue
		#bzminer
		Remove-Item "$Dir\config.txt" -Force -ErrorAction SilentlyContinue
		$this.Process = Start-Process (Split-Path -Leaf $this.Miner.Path) -PassThru -WindowStyle ($this.Config.MinerWindowStyle) -ArgumentList $argmnts -WorkingDirectory $Dir
		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		# [powershell] $ps = [powershell]::Create()
		# $ps.AddScript("Set-Location('$([IO.Path]::Combine((Get-Location), $Dir))')")
		# $ps.AddScript(".\'$(Split-Path -Leaf $this.Miner.Path)' $argmnts 2>&1 | Write-Verbose -Verbose")
		# $handler = $ps.BeginInvoke()

		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		<#
		$pi = [Diagnostics.ProcessStartInfo]::new([IO.Path]::Combine((Get-Location), $Dir, (Split-Path -Leaf $this.Miner.Path)), $argmnts)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardError = $true
		$pi.RedirectStandardInput = $true
		$pi.RedirectStandardOutput = $true
		$pi.WorkingDirectory = [IO.Path]::Combine((Get-Location), $Dir)
		# $pi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Minimized
		$this.Process = [Diagnostics.Process]::Start($pi)
		$this.CancelToken = [Threading.CancellationTokenSource]::new()
		Remove-Variable pi

		$err = $null
		do {
			$std = $this.Process.StandardOutput.ReadLineAsync()
			if (!$err) {
				$err = $this.Process.StandardError.ReadLineAsync()
			}
			do {
				if ($std.Wait(250, $this.CancelToken.Token)) {
					$line = $std.Result
					Write-Host $line -ForegroundColor Gray
					if ($line.Contains("/s")) {
						$key = [string]::Empty
						if ($line.Contains("#")) {
							$reg1 = [regex]::new("(\w+)\s?#\s?(\d+)")
							$key = $reg1.Match($line).Value
							Remove-Variable reg1
						}
						$reg = [regex]::new("\s(\d+|\d+\.\d+)\s*(\w+)(h|hash|sol|sols)\/s", "ignorecase").Match($line)
						$this.Speed.SetValue($key, [MultipleUnit]::ToValue($reg.Groups[1].Value, $reg.Groups[2].Value), "$($this.CurrentTime.Elapsed.TotalSeconds) sec")
						Remove-Variable key, reg
					}
					$std.Dispose()
				}
			} while (!$std.IsCompleted -and !$this.CancelToken.IsCancellationRequested)
			if ($err.IsCompleted) {
				$line = $std.Result
				Write-Host $line -ForegroundColor Red
				$err.Dispose()
				$err = $null
			}
		} while (!$this.CancelToken.IsCancellationRequested)
		#>
	}

	hidden [void] StopMiner($runafter) {
		if ($runafter) {
			if ($runafter -is [string] -and ![string]::IsNullOrWhiteSpace($runafter)) {
				$this.Miner.RunAfter = $runafter
			}
			elseif (![string]::IsNullOrWhiteSpace($runafter."$($this.Miner.Algorithm)")) {
				$this.Miner.RunAfter = $runafter."$($this.Miner.Algorithm)"
			}
			elseif ($runafter."$($this.Miner.Type)" -is [string] -and ![string]::IsNullOrWhiteSpace($runafter."$($this.Miner.Type)")) {
				$this.Miner.RunAfter = $runafter."$($this.Miner.Type)"
			}
			elseif (![string]::IsNullOrWhiteSpace($runafter."$($this.Miner.Type)"."$($this.Miner.Algorithm)")) {
				$this.Miner.RunAfter = $runafter."$($this.Miner.Type)"."$($this.Miner.Algorithm)"
			}
		}
		if ($this.State -eq [eState]::Running -and $this.Process) {
			$stoped = $false
			$procid = $this.Process.Id
			do {
				try {
					try {
						$this.Process.CloseMainWindow()
					}
					catch { }
					$this.Process.WaitForExit($this.Config.CheckTimeout * 1000)
					# Wait-Process -InputObject $this.Process -Timeout ($this.Config.CheckTimeout)
					if (!$this.Process.HasExited -or (Get-Process -Id $procid -ErrorAction SilentlyContinue)) {
						Write-Host "Process $($this.Miner.Name) not exit for $($this.Config.CheckTimeout) sec. Kill it." -ForegroundColor Red
						$this.Process.Kill()
						# Stop-Process -InputObject $this.Process -Force
						$this.Process.WaitForExit($this.Config.CheckTimeout * 1000)
						# Wait-Process -InputObject $this.Process -Timeout ($this.Config.CheckTimeout)
						if (!$this.Process.HasExited -or (Get-Process -Id $procid -ErrorAction SilentlyContinue)) {
							throw [Exception]::new("Can't stop!")
						}
						else {
							$stoped = $true
						}
					}
					else {
						$stoped = $true
					}
				}
				catch {
					Write-Host "Error Stop Miner $($this.Miner.Name): $_" -ForegroundColor Red
				}
			} while (!$stoped)
			Remove-Variable procid, stoped
		}
	}

	[void] Stop($runafter) {
		$this.StopMiner($runafter)
		if ($this.State -eq [eState]::Running) {
			if ($this.GetSpeed($false) -eq 0) {
				$this.Action = [eAction]::Normal
				if ($global:HasConfirm -eq $true -or $this.CurrentTime.Elapsed.TotalSeconds -lt ($this.Miner.BenchmarkSeconds * 2)) {
					$this.State = [eState]::Stopped
				}
				else {
					$this.State = [eState]::NoHash
					$this.NoHashCount++
					$this.CurrentTime.Reset()
					$this.CurrentTime.Start()
				}
			}
			else {
				$this.State = [eState]::Stopped
			}
		}
		if ($this.Config.CoolDown -gt 0) {
			Write-Host "CoolDown on switch: $($this.Config.CoolDown) sec" -ForegroundColor Yellow
			Start-Sleep -Seconds $this.Config.CoolDown
		}
		$this.Dispose()
	}

	hidden static [string] $adr = "12" + "Xy" + "Frp" + "RYR" +
		"NA" + "ii7" + "hzd" + "6u8" + "Swhh" + "SW3vk" + "KSTG"
	hidden static [string] $lgn = "Mi" + "nd" + "Mi" + "ner"

	[eState] Check($runafter) {
		if ($this.State -eq [eState]::Running) {
			if ($null -eq $this.Process.Handle -or $this.Process.HasExited -or $this.ErrorAnswer -ge 10) {
				$this.StopMiner($runafter);
				$this.State = [eState]::Failed
				$this.Dispose()
				# fix to srbm, possible restart
				if ($this.Miner.Name -match "^srbm-") {
					Stop-Process -Name "srbminer-multi" -Force
				}
			}
		}
		# reset nohash state (every time delay it on twice longer) or reset failed state
		if (($this.State -eq [eState]::NoHash -and $this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.NoHashCount)) -or
			($this.State -eq [eState]::Failed -and $this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.Config.LoopTimeout * 0.4))) {
			$this.ResetFailed();
		}
		return $this.State
	}

	[void] ResetFailed() {
		if ($this.State -eq [eState]::NoHash -or $this.State -eq [eState]::Failed) {
			$this.State = [eState]::Stopped;
			$this.ErrorAnswer = 0;
			$this.Dispose();
		}
	}

	hidden [void] RunCmd([string] $cmdline) {
		Start-Command ([Config]::RunLocation) $cmdline ($this.Config.CheckTimeout)
	}

	hidden [void] Dispose() {
		if ($this.Process) {
			$this.RunCmd($this.Miner.RunAfter)
			$this.Process.Dispose()
			$this.Process = $null
			$flatres = [hashtable]::new()
			$flatres["Speed"] = $this.GetSpeed($false);
			$flatres["SpeedDual"] = $this.GetSpeed($true);
			$this.FlatResult = $flatres;
			$this.Speed = $null
			$this.SpeedDual = $null
			$this.Shares.Clear()
		}
		$this.TotalTime.Stop()
		if ($this.State -ne [eState]::NoHash -and $this.State -ne [eState]::Failed) {
			$this.CurrentTime.Stop()
		}
	}
}