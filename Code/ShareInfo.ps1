<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class ShareInfo {
	[decimal] $Value
	[Diagnostics.Stopwatch] $SW

	ShareInfo([decimal] $value) {
		$this.Value = $value
		$this.SW = [Diagnostics.Stopwatch]::StartNew()
	}
}

class ShareList {
	hidden [Collections.Generic.List[ShareInfo]] $list

	ShareList() {
		$this.list = [Collections.Generic.List[ShareInfo]]::new()
	}

	[void] Add([decimal] $value) {
		$this.list.Add([ShareInfo]::new($value))
	}

	[decimal] Get([int] $totalseconds) {
		$this.Actual($totalseconds)
		return if ($this.list.Length -gt 0) { $this.list[$this.list.Length - 1].Value - $this.list[0].Value + 1 } else { return 0 }
	}

	hidden [void] Actual([int] $totalseconds) {
		[bool] $removed = $true
		while ($this.list.Length -gt 0 -and $removed) {
			if ($this.list[0].SW.Elapsed.TotalSeconds -gt $totalseconds) {
				$this.list.RemoveAt(0)
			}
			else {
				$removed = $false
			}
		}
	}
}

class Shares {
	hidden [ShareList] $Total;
	hidden [ShareList] $Accepted;
	hidden [ShareList] $Rejected;

	Shares() {
		$this.Total = [ShareList]::new();
		$this.Accepted = [ShareList]::new();
		$this.Rejected = [ShareList]::new();
	}

	[void] AddTotal([decimal] $value) {
		$this.Total.Add($value);
	}

	[void] AddAccepted([decimal] $value) {
		$this.Accepted.Add($value);
	}

	[void] AddRejected([decimal] $value) {
		$this.Rejected.Add($value);
	}

	# return from 1 (all accepted) to 0 (all rejected)
	[decimal] Get([int] $totalseconds) {
		$ttl = $this.Total.Get($totalseconds);
		$acc = $this.Accepted.Get($totalseconds);
		$rej = $this.Rejected.Get($totalseconds);
		if ($ttl -gt 0 -and $acc -gt 0 -and $rej -gt 0) {
			throw [Exception]::new("Must be set only two from AddTotal, AddAccepted and AddRejected in Shares.");
		}
		if ($ttl -eq 0) {
			$ttl = $acc + $rej;
		}
		elseif ($acc -eq 0) {
			$acc = $ttl - $rej;
		}
		# exclude division by zero
		if ($ttl -le 0 -or $acc -le 0) {
			return 0;
		}
		# 98 * 1 / 100
		$result = $acc / $ttl;
		if ($result -gt 1) { $result = 1 }
		return $result;
	}
}