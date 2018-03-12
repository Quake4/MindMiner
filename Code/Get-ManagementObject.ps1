<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ManagementObject ([Parameter(Mandatory)][string] $Query, [Parameter(Mandatory)][scriptblock] $Script) {
	if (![string]::IsNullOrWhiteSpace($Query) -and $Script) {
		[Management.ManagementObjectSearcher] $mo = $null
		[Management.ManagementObjectCollection] $items = $null
		try {
			$mo = [Management.ManagementObjectSearcher]::new($Query)
			$items = $mo.Get()
			&$Script $items
		}
		catch {
			Write-Host "Get-ManagementObject exception: $_" -ForegroundColor Red
		}
		finally {
			if ($items -is [IDisposable]) { $items.Dispose() }
			if ($mo -is [IDisposable]) { $mo.Dispose() }
		}
	}
}