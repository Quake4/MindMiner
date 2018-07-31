<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\HumanInterval.ps1

class StatInfo {
	[decimal] $Value
	[datetime] $Change
	[datetime] $Zero

	StatInfo([decimal] $value) {
		$this.Value = $value
		$this.Change = (Get-Date).ToUniversalTime()
	}

	StatInfo([PSCustomObject] $value) {
		$value | Get-Member -MemberType NoteProperty | ForEach-Object {
			$this."$($_.Name)" = $value."$($_.Name)"
		}
	}

	[decimal] SetValue([decimal] $value, [string] $interval) {
		return $this.SetValue($value, $interval, 0.5)
	}
		
	[decimal] SetValue([decimal] $value, [string] $interval, [decimal] $maxpercent) {
		$now = (Get-Date).ToUniversalTime()
		if (![string]::IsNullOrWhiteSpace($interval)) {
			$intervalSeconds = [HumanInterval]::Parse($interval).TotalSeconds
			if ($value -eq 0 -and ($now - $this.Zero).TotalSeconds -ge $intervalSeconds) {
				$this.Value = $value
			}
			else {
				$span = [Math]::Min(($now - $this.Change).TotalSeconds / $intervalSeconds, $maxpercent)
				$this.Value = $this.Value - $span * $this.Value + $span * $value
				Remove-Variable span
			}
			Remove-Variable intervalSeconds
		}
		else {
			$this.Value = $value
		}
		$this.Change = $now
		if ($value -gt 0) {
			$this.Zero = $now
		}
		Remove-Variable now
		return $this.Value
	}
}

class StatGroup {
	[Collections.Generic.Dictionary[string, StatInfo]] $Values
	[bool] $HasChanges

	StatGroup() {
		$this.Values = [Collections.Generic.Dictionary[string, StatInfo]]::new()
		$this.HasChanges = $true
	}

	StatGroup([PSCustomObject] $value) {
		$this.Values = [Collections.Generic.Dictionary[string, StatInfo]]::new()
		$this.HasChanges = $false
		$value | Get-Member -MemberType NoteProperty | ForEach-Object {
			$this.Values.Add($_.Name, [StatInfo]::new($value."$($_.Name)"))
		}
	}

	[decimal] SetValue([decimal] $value) {
		return $this.SetValue([string]::Empty, $value, [string]::Empty)
	}

	[decimal] SetValue([string] $key, [decimal] $value) {
		return $this.SetValue($key, $value, [string]::Empty)
	}

	[decimal] SetValue([string] $key, [decimal] $value, [string] $interval) {
		return $this.SetValue($key, $value, $interval, 0.5)
	}
	
	[decimal] SetValue([string] $key, [decimal] $value, [string] $interval, [decimal] $maxpercent) {
		$this.HasChanges = $true
		if (!$this.Values.ContainsKey($key)) {
			$this.Values.Add($key, [StatInfo]::new($value))
			return $value
		}
		else {
			$item = $this.Values[$key]
			return $item.SetValue($value, $interval, $maxpercent)
		}
	}

	[decimal] GetValue() {
		return $this.GetValue([string]::Empty)
	}

	[decimal] GetValue([string] $key) {
		if (!$this.Values.ContainsKey($key)) {
			return 0
		}
		else {
			return $this.Values[$key].Value
		}
	}

	[void] DelValues([string] $interval) {
		if (![string]::IsNullOrWhiteSpace($interval)) {
			$now = (Get-Date).ToUniversalTime()
			$intervalSeconds = [HumanInterval]::Parse($interval).TotalSeconds
			($this.Values.Keys | Where-Object { $_ }) | ForEach-Object {
				if (($now - $this.Values[$_].Change).TotalSeconds -ge $intervalSeconds) {
					$this.Values.Remove($_);
					$this.HasChanges = $true
				}
			}
			Remove-Variable intervalSeconds, now
		}
	}
}

class StatCache {
	hidden [Collections.Generic.Dictionary[string, StatGroup]] $Values

	StatCache() {
		$this.Values = [Collections.Generic.Dictionary[string, StatGroup]]::new()
	}

	[decimal] SetValue([string] $filename, [string] $key, [decimal] $value) {
		return $this.SetValue($filename, $key, $value, [string]::Empty)
	}

	[decimal] SetValue([string] $filename, [string] $key, [decimal] $value, [string] $interval) {
		return $this.SetValue($filename, $key, $value, $interval, 0.5)
	}
	
	[decimal] SetValue([string] $filename, [string] $key, [decimal] $value, [string] $interval, [decimal] $maxpercent) {
		if (!$this.Values.ContainsKey($Filename)) {
			$this.Values.Add($filename, [StatGroup]::new())
		}
		return $this.Values[$filename].SetValue($key, $value, $interval, $maxpercent)
	}

	[decimal] GetValue([string] $filename) {
		return $this.GetValue($filename, [string]::Empty)
	}
	
	[decimal] GetValue([string] $filename, [string] $key) {
		if (!$this.Values.ContainsKey($Filename)) {
			return 0
		}
		return $this.Values[$filename].GetValue($key)
	}

	[void] DelValues([string] $filename, [string] $interval) {
		if ($this.Values.ContainsKey($Filename)) {
			$this.Values[$filename].DelValues($interval)
		}
	}

	[void] Write([string] $dir) {
		[StatCache]::CheckDir($dir)
		# find all changed stats and save
		$this.Values.Keys | Where-Object { $this.Values."$_".HasChanges -eq $true } | ForEach-Object {
			$this.Values."$_".Values | ConvertTo-Json | Out-File -FilePath "$dir\$_.txt" -Force
			$this.Values."$_".HasChanges = $false
		}
	}

	static [StatCache] Read([string] $dir) {
		[StatCache]::CheckDir($dir)
		$result = [StatCache]::new()
		Get-ChildItem $dir | ForEach-Object {
			try {
				$stat = $_ | Get-Content | ConvertFrom-Json
				$gn = [IO.Path]::GetFileNameWithoutExtension($_)
				$result.Values.Add($gn, [StatGroup]::new($stat))
				Remove-Variable gn, stat
			}
			catch {
				Write-Host "Statistic read error: $_" -ForegroundColor Red
			}
		}
		return $result
	}

	static hidden [void] CheckDir([string] $dir) {
		if (!(Test-Path $dir)) { New-Item $dir -ItemType Directory -Force }
	}
}