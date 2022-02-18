<#
MindMiner  Copyright (C) 2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class ShareInfo {
	[decimal] $Value
	[Diagnostics.Stopwatch] $SW

	ShareInfo([decimal] $value) {
		$this.Value = $value
		$this.Reset();
	}

	[void] Reset() {
		$this.SW = [Diagnostics.Stopwatch]::StartNew()
	}
}

class ShareList {
	hidden [Collections.Generic.List[ShareInfo]] $list

	ShareList() {
		$this.list = [Collections.Generic.List[ShareInfo]]::new()
	}

	[void] Add([decimal] $value) {
		if ($this.list.Count -gt 0) {
			$item = $this.list[$this.list.Count - 1];
			if ($item.Value -eq $value) {
				$item.Reset();
				return
			}
		}
		$this.list.Add([ShareInfo]::new($value))
	}

	[decimal] GetOne() {
		if ($this.list.Count -eq 1) {
			return $this.list[0].Value;
		}
		return -1;
	}

	[decimal] Get([int] $totalseconds) {
		$this.Actual($totalseconds)
		if ($this.list.Count -le 0) { return 0 }
		return $this.list[$this.list.Count - 1].Value - $this.list[0].Value;
	}

	hidden [void] Actual([int] $totalseconds) {
		[bool] $removed = $true
		while ($this.list.Count -gt 0 -and $removed) {
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
	hidden [decimal] $Value;

	Shares() {
		$this.Clear();
	}

	[void] Clear() {
		$this.Value = 0;
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

	[void] SetValue([decimal] $value) {
		$this.Value = $value;
	}

	[bool] HasValue([int] $totalseconds, [int] $minCount) {
		if ($this.Value -gt 0) {
			return $true;
		}
		$ttl = $this.Total.Get($totalseconds);
		$acc = $this.Accepted.Get($totalseconds);
		$rej = $this.Rejected.Get($totalseconds);
		if (($ttl + $acc + $rej) -ge $minCount) {
			return $true;
		}
		$ttl = $this.Total.GetOne();
		$acc = $this.Accepted.GetOne();
		$rej = $this.Rejected.GetOne();
		if (($ttl -ge 0 -and $rej -ge 0 -and $ttl -ge $minCount) -or
			($ttl -ge 0 -and $acc -ge 0 -and $ttl -ge $minCount) -or
			($acc -ge 0 -and $rej -ge 0 -and ($acc + $rej) -ge $minCount)) {
			return $true;
		}
		return $false;
	}

	# return from 1 (all accepted) to 0 (all rejected)
	[decimal] Get([int] $totalseconds) {
		if ($this.Value -gt 0) {
			return $this.Value;
		}
		$ttl = $this.Total.GetOne();
		$acc = $this.Accepted.GetOne();
		$rej = $this.Rejected.GetOne();
		if (($ttl -ge 0 -and $rej -ge 0 -and $ttl -gt 0) -or
			($ttl -ge 0 -and $acc -ge 0 -and $ttl -gt 0) -or
			($acc -ge 0 -and $rej -ge 0 -and ($acc + $rej) -gt 0)) {
			if ($ttl -eq -1) { $ttl = 0 }
			if ($acc -eq -1) { $acc = 0 }
			if ($rej -eq -1) { $rej = 0 }
		}
		else {
			$ttl = $this.Total.Get($totalseconds);
			$acc = $this.Accepted.Get($totalseconds);
			$rej = $this.Rejected.Get($totalseconds);
		}
		if ($ttl -eq 0 -and $acc -eq 0 -and $rej -eq 0) {
			return 1;
		}
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