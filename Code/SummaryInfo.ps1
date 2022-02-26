<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class SummaryInfo {
	[int] $Loop
	[Diagnostics.Stopwatch] $TotalTime
	[Diagnostics.Stopwatch] $LoopTime
	[Diagnostics.Stopwatch] $FeeTime
	[Diagnostics.Stopwatch] $ServiceTime
	[Diagnostics.Stopwatch] $RateTime
	[timespan] $RateTimeout
	[Diagnostics.Stopwatch] $SendApiTime
	hidden [bool] $Service

	SummaryInfo([timespan] $minutes, [bool] $service) {
		$this.Loop = 1
		$this.TotalTime = [Diagnostics.Stopwatch]::new()
		$this.LoopTime = [Diagnostics.Stopwatch]::new()
		$this.FeeTime = [Diagnostics.Stopwatch]::new()
		$this.ServiceTime = [Diagnostics.Stopwatch]::new()
		$this.RateTime = [Diagnostics.Stopwatch]::new()
		$this.RateTimeout = $minutes
		$this.SendApiTime = [Diagnostics.Stopwatch]::new()
		$this.Service = $service
	}

	[bool] ServiceRunnig() {
		return $this.ServiceTime.IsRunning -or $this.FeeTime.IsRunning
	}

	[string] ToString() {
		$elapsed = [SummaryInfo]::Elapsed($this.UpTime())
		$nl = [Environment]::NewLine
		$srvc = if ($this.Service) { ("  Service Time: {0} ({1:P1})" -f [SummaryInfo]::Elapsed($this.ServiceTime.Elapsed),
			($this.ServiceTime.Elapsed.TotalMilliseconds / $this.TotalTime.Elapsed.TotalMilliseconds)) + $nl } else { "" }
		return [string]::Empty +
			(" Loop/Used RAM: {0,$($elapsed.Length)}/{1:N1} Mb" -f $this.Loop, ([GC]::GetTotalMemory(0)/1mb)) + $nl +
			("  Run/Fee Time: {0} ({1:P1})" -f ("{0,$($elapsed.Length)}/{1}" -f [SummaryInfo]::Elapsed($this.TotalTime.Elapsed), [SummaryInfo]::Elapsed($this.FeeTime.Elapsed)),
				($this.FeeTime.Elapsed.TotalMilliseconds / $this.TotalTime.Elapsed.TotalMilliseconds)) + $nl + $srvc +
			("Boot/Rate Time: {0}" -f ("{0,$($elapsed.Length)}/{1}" -f $elapsed, [SummaryInfo]::Elapsed($this.RateTimeout - $this.RateTime.Elapsed)))
	}

	hidden [Collections.ArrayList] $clmns
	[Collections.ArrayList] Columns() {
		if (!$this.clmns) {
			$this.clmns = [Collections.ArrayList]::new()
			$this.clmns.AddRange(@(
				@{ Label="Loop"; Expression = { "{0:N0}" -f $_.Loop } }
				@{ Label="Used RAM"; Expression = { "{0:N1} Mb" -f ([GC]::GetTotalMemory(0)/1mb) } }
				@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } }
			))
			if ($this.Service) {
				$this.clmns.AddRange(@(
					@{ Label="Service Time"; Expression = { "{0} ({1:P1})" -f [SummaryInfo]::Elapsed($_.ServiceTime.Elapsed), ($_.ServiceTime.Elapsed.TotalMilliseconds / $_.TotalTime.Elapsed.TotalMilliseconds) } }
				))
			}
			$this.clmns.AddRange(@(
				@{ Label="Fee Time"; Expression = { "{0} ({1:P1})" -f [SummaryInfo]::Elapsed($_.FeeTime.Elapsed), ($_.FeeTime.Elapsed.TotalMilliseconds / $_.TotalTime.Elapsed.TotalMilliseconds) } }
				@{ Label="Boot Time"; Expression = { [SummaryInfo]::Elapsed($_.UpTime()) } }
				@{ Label="Rate Time"; Expression = { [SummaryInfo]::Elapsed($_.RateTimeout - $_.RateTime.Elapsed) } }
			))
		}
		return $this.clmns
	}

	hidden [Collections.ArrayList] $clmnsapi
	[Collections.ArrayList] ColumnsApi() {
		if (!$this.clmnsapi) {
			$this.clmnsapi = [Collections.ArrayList]::new()
			$this.clmnsapi.AddRange(@(
				@{ Label="boottime"; Expression = { [decimal]::Round($_.UpTime().TotalSeconds) } }
				@{ Label="runtime"; Expression = { [decimal]::Round($_.TotalTime.Elapsed.TotalSeconds) } }
				@{ Label="feetime"; Expression = { [decimal]::Round($_.FeeTime.Elapsed.TotalSeconds) } }
				@{ Label="servicetime"; Expression = { [decimal]::Round($_.ServiceTime.Elapsed.TotalSeconds) } }
			))
		}
		return $this.clmnsapi
	}

	[void] FStart() {
		$this.FeeTime.Start()
	}

	[void] FStop() {
		$this.FeeTime.Stop()
	}

	static [string] Elapsed([timespan] $ts) {
		$minus = if ($ts.TotalMilliseconds -lt 0) { "-" } else { [string]::Empty }
		$f = "{1:00}:{2:00}:{3:00}"
		if ($ts.Days) { $f = "{0:0}." + $f }
		return "$minus$f" -f [Math]::Abs($ts.Days), [Math]::Abs($ts.Hours), [Math]::Abs($ts.Minutes), [Math]::Abs($ts.Seconds)
	}

	hidden [timespan] UpTime() {
		[Management.ManagementBaseObject] $os = $null;
		try {
			$os = Get-WmiObject -Class Win32_OperatingSystem
			return (Get-Date) - $os.ConvertToDateTime($os.lastbootuptime);
		}
		finally {
			if ($os -is [IDisposable]) { $os.Dispose() }
		}
		return [timespan]::new(0)
	}
}