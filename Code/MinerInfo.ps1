<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

enum eMinerType {
	CPU = 0
	nVidia
	AMD
	Intel
}

class MinerInfo {
	[string] $Name
	[string] $Algorithm
	[string] $DualAlgorithm
	[string] $Type
	[bool] $TypeInKey
	[string] $API
	[string] $URI
	[string] $Path
	[string] $Pass
	[string] $ExtraArgs
	[string] $Arguments
	[int] $Port
	[string] $Pool
	[string] $PoolKey
	[Priority] $Priority
	[Priority] $DualPriority
	[int] $BenchmarkSeconds
	[string] $RunBefore
	[string] $RunAfter
	[decimal] $Fee

	hidden [string] $Filename
	hidden [string] $Key
	hidden [string] $ExKey
	hidden [string] $UniqueKey
	hidden [string] $PowerFilename

	[bool] IsDual() {
		return ![string]::IsNullOrWhiteSpace($this.DualAlgorithm)
	}

	[bool] Exists([string] $parent) {
		return (Test-Path ([IO.Path]::Combine($parent, $this.Path)))
	}

	[string] GetCommandLine() {
		return "$($this.Path) $($this.Arguments)"
	}

	[string] GetFilename() {
		if (!$this.Filename) {
			$this.Filename = "$($this.Name)"
		}
		return $this.Filename
	}

	[string] GetPowerFilename() {
		if (!$this.PowerFilename) {
			$this.PowerFilename = "$($this.Name).power"
		}
		return $this.PowerFilename
	}

	[string] GetKey() {
		if (!$this.Key) {
			$this.Key = [string]::Empty
			if ($this.TypeInKey -eq $true) {
				$this.Key += "$($this.Type)_"
			}
			$this.Key += "$($this.Algorithm)"
			if (![string]::IsNullOrWhiteSpace($this.DualAlgorithm)) {
				$this.Key += "+$($this.DualAlgorithm)"
			}
			if (![string]::IsNullOrWhiteSpace($this.ExtraArgs)) {
				$this.Key += "_"
				foreach ($each in $this.ExtraArgs.ToCharArray()) {
					if ([char]::IsDigit($each) -or [char]::IsLetter($each)) {
						$this.Key += $each;
					}
				}
			}
		}
		return $this.Key
	}

	[string] GetKey([bool] $dual) {
		return $this.GetKey() + "$(if ($dual) { "_$($this.DualAlgorithm)" } else { [string]::Empty })"
	}

	[string] GetExKey() {
		if (!$this.ExKey) {
			$this.ExKey = "$($this.GetFilename())_$($this.GetKey())"
		}
		return $this.ExKey
	}

	[string] GetUniqueKey() {
		if (!$this.UniqueKey) {
			$this.UniqueKey = "$($this.GetFilename())_$($this.GetKey())_$($this.PoolKey)_$($this.Priority)_$($this.Arguments)"
		}
		return $this.UniqueKey
	}

	[string] ToString() {
		return $this | Select-Object Name, Algorithm, ExtraArgs, Path, Arguments
	}
}