<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

enum eMinerType {
	CPU
	nVidia
	AMD
	Intel
}

class MinerInfo {
	[string] $Name
	[string] $Algorithm
	[string] $Type
	[string] $API
	[string] $URI
	[string] $Path
	[string] $ExtraArgs
	[string] $Arguments
	[int] $Port
	[string] $Pool
	[int] $BenchmarkSeconds

	hidden [string] $Filename
	hidden [string] $Key
	hidden [string] $UniqueKey

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

	[string] GetKey() {
		if (!$this.Key) {
			$this.Key = "$($this.Algorithm)"
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

	[string] GetUniqueKey() {
		if (!$this.UniqueKey) {
			$this.UniqueKey = "$($this.GetFilename())_$($this.GetKey())_$($this.Arguments)"
		}
		return $this.UniqueKey
	}

	[string] ToString() {
		return $this | Select-Object Name, Algorithm, ExtraArgs, Path, Arguments
	}
}