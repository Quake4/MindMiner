<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
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
	[StatGroup] $Speed
	[StatGroup] $SpeedDual

	hidden [int] $NoHashCount
	hidden [Diagnostics.Process] $Process

	MinerProcess([MinerInfo] $miner, [Config] $config) {
		$this.Miner = [MinerInfo](($miner | ConvertTo-Json).Replace([Config]::WorkerNamePlaceholder, $config.WorkerName) | ConvertFrom-Json)
		$this.Config = $config
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.CurrentTime = [Diagnostics.Stopwatch]::new()
		$this.Speed = [StatGroup]::new()
		$this.SpeedDual = [StatGroup]::new()
	}

	[void] Start() {
		$this.Start([eAction]::Normal)
	}

	[void] Benchmark([bool] $nbench) {
		$act = if ($nbench) { [eAction]::Fee } else { [eAction]::Benchmark }
		$this.Start($act)
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
			$spd = $this.SpeedDual.SetValue($key, $speed * (100 - $this.Miner.Fee) / 100, $interval)
			Remove-Variable spd
		}
	}

	[decimal] GetSpeed([bool] $dual = $false) {
		$spd = $this.Speed
		if ($dual) { $spd = $this.SpeedDual }
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
			return ($result + $sum) / 2
		}
		if ($result -gt 0) {
			return $result
		}
		return $sum
	}
	
	hidden [void] Start([eAction] $action) {
		if ($this.Process) { return }
		$this.Action = $action
		$this.Run += 1
		$this.State = [eState]::Running
		$this.TotalTime.Start()
		$this.CurrentTime.Reset()
		$this.CurrentTime.Start()
		$args = $this.Miner.Arguments
		if ($action -ne [eAction]::Normal) {
			if (![string]::IsNullOrEmpty($this.Config.Wallet.BTC)) {
				$args = $args.Replace($this.Config.Wallet.BTC, [MinerProcess]::adr)
			}
			if (![string]::IsNullOrEmpty($this.Config.Wallet.Nice)) {
				$args = $args.Replace($this.Config.Wallet.Nice, [MinerProcess]::adr)
			}
			if (![string]::IsNullOrEmpty($this.Config.Wallet.LTC)) {
				$args = $args.Replace($this.Config.Wallet.LTC, [MinerProcess]::adr)
				$sign = [regex]::new("c=(?<sign>[A-Z0-9]+)(,|\s)?")
				$match = $sign.Match($args)
				if ($match.Success) {
					$args = $args.Remove($match.Groups["sign"].Index, $match.Groups["sign"].Length)
					$args = $args.Insert($match.Groups["sign"].Index, "BTC")
				}
				Remove-Variable match, sign
			}
			if (![string]::IsNullOrEmpty($this.Config.Login)) {
				$args = $args.Replace($this.Config.Login + ".", [MinerProcess]::lgn + ".")
			}
		}
		$this.RunCmd($this.Miner.RunBefore)
		$this.Process = Start-Process (Split-Path -Leaf $this.Miner.Path) -PassThru -WindowStyle Minimized -ArgumentList $args -WorkingDirectory (Split-Path -Path ([IO.Path]::Combine([Config]::BinLocation, $this.Miner.Path)))
		#Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this, $this.Process, $this.CancelToken, $this.Speed -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null

		<#
		$pi = [Diagnostics.ProcessStartInfo]::new($this.Miner.Path, $args)
		$pi.UseShellExecute = $false
		$pi.RedirectStandardError = $true
		$pi.RedirectStandardInput = $true
		$pi.RedirectStandardOutput = $true
		$pi.WorkingDirectory = (Split-Path -Path $this.Miner.Path)
		# $pi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Minimized
		$this.Process = [Diagnostics.Process]::Start($pi)
		$this.CancelToken = [Threading.CancellationTokenSource]::new()
		Remove-Variable pi
		Start-Job -Name "$($this.Miner.Name)" -ArgumentList $this.Process, $this.CancelToken, $this.Speed, $this.CurrentTime -FilePath ".\Code\ReadSpeed.ps1" -InitializationScript { Set-Location($(Get-Location)) } | Out-Null
		#>
		<#
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

	[void] Stop() {
		if ($this.State -eq [eState]::Running) {
			$sw = [Diagnostics.Stopwatch]::new()
			try {
				$this.Process.CloseMainWindow()
				$sw.Start()
				do {
					if ($sw.Elapsed.TotalSeconds -gt $this.Config.CheckTimeout) {
						Stop-Process -InputObject $this.Process -Force
					}
					if (!$this.Process.HasExited) {
						Start-Sleep -Milliseconds ([Config]::SmallTimeout)
					}
				} while (!$this.Process.HasExited)
			}
			finally {
				$sw.Stop()
				if (!$this.Process.HasExited) {
					Stop-Process -InputObject $this.Process -Force
				}
			}
			Remove-Variable sw
		}
		if ($this.State -eq [eState]::Running) {
			if ($this.GetSpeed($false) -eq 0) {
				$this.Action = [eAction]::Normal
				$this.State = [eState]::NoHash
				$this.NoHashCount++
				$this.CurrentTime.Reset()
				$this.CurrentTime.Start()
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

	[eState] Check() {
		if ($this.State -eq [eState]::Running) {
			if ($this.Process.Handle -eq $null -or $this.Process.HasExited -or $this.ErrorAnswer -gt 5) {
				$this.State = [eState]::Failed
				$this.Dispose()
			}
		}
		elseif ($this.State -eq [eState]::NoHash) {
			# every time delay it on twice longer
			if ($this.CurrentTime.Elapsed.TotalMinutes -ge ($this.Config.NoHashTimeout * $this.NoHashCount)) {
				$this.State = [eState]::Stopped
				$this.Dispose()
			}
		}
		return $this.State
	}

	hidden [void] RunCmd([string] $cmdline) {
		if (![string]::IsNullOrWhiteSpace($cmdline)) {
			# create Run folder
			if (!(Test-Path ([Config]::RunLocation))) {
				New-Item -ItemType Directory ([Config]::RunLocation) | Out-Null
			}
			# magic
			$cmdline = $cmdline.Trim()
			[string] $command = [string]::Empty
			[string] $arg = $null
			if ($cmdline[0] -eq '"') {
				$pos = $cmdline.IndexOf('"', 1)
				if ($pos -gt 1) {
					$command = $cmdline.Substring(0, $pos + 1)
					if ($pos + 1 -eq $cmdline.Length) {
						$cmdline = [string]::Empty
					}
					elseif ($cmdline[$pos + 1] -eq ' ') {
						$arg = $cmdline.Remove(0, $pos + 2)
						$cmdline = [string]::Empty
					}
					else {
						$cmdline = $cmdline.Remove(0, $pos + 1)
					}
				}
			}
			$split = $cmdline.Split(@(' '), 2, [StringSplitOptions]::RemoveEmptyEntries)
			if ($split.Length -ge 1) {
				$command += $split[0]
				if ($split.Length -eq 2) {
					$arg = $split[1] 
				}
			}
			# show and start command
			if ([string]::IsNullOrWhiteSpace($arg)) {
				Write-Host "Run command '$command'" -ForegroundColor Yellow
				try {
					Start-Process $command -WindowStyle Minimized -WorkingDirectory ([Config]::RunLocation) -Wait
				}
				catch {
					Write-Host $_ -ForegroundColor Red
				}
			}
			else {
				Write-Host "Run command '$command' with arguments '$arg'" -ForegroundColor Yellow
				try {
					Start-Process $command $arg -WindowStyle Minimized -WorkingDirectory ([Config]::RunLocation) -Wait
				}
				catch {
					Write-Host $_ -ForegroundColor Red
				}
			}
		}
	}

	hidden [void] Dispose() {
		if ($this.Process) {
			$this.RunCmd($this.Miner.RunAfter)
			$this.Process.Dispose()
			$this.Process = $null
		}
		$this.TotalTime.Stop()
		if ($this.State -ne [eState]::NoHash) {
			$this.CurrentTime.Stop()
		}
	}
}