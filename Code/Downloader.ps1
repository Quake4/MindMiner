<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$Download = $args

$Download | ForEach-Object {
	$URI = $_.URI
	$Path = $_.Path
	$Dir = Split-Path -Path $Path
	$FN = Split-Path -Leaf $URI
	$Archive = [IO.Path]::Combine($Dir, $FN)
	$File = [IO.Path]::Combine($Dir, $FN)

	"'$URI' '$Path' '$Dir' '$FN' '$Archive' " | Out-File "$FN.txt"

	if (![string]::IsNullOrWhiteSpace($Dir) -and !(Test-Path $Dir)) {
		New-Item -ItemType Directory $Dir | Out-Null
	}

	if (!(Test-Path $Path)) {
		try {
			if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
				[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
			}
			$req = Invoke-WebRequest $URI -OutFile $Archive -PassThru -ErrorAction Stop -UseBasicParsing
			# names not match - upack
			if ((Split-Path -Leaf $Path) -ne $FN) {
				if ([string]::IsNullOrWhiteSpace($Dir)) {
					Start-Process "7z" "x $Archive -y -spe" -Wait -WindowStyle Minimized
				}
				else {
					Start-Process "7z" "x $Archive -o$Dir -y -spe" -Wait -WindowStyle Minimized
				}
				# remove archive
				Remove-Item $Archive -Force
				if (![IO.File]::Exists($Path)) {
					# if has one subfolder - delete him
					Get-ChildItem $Dir | Where-Object PSIsContainer -EQ $true | ForEach-Object {
						$parent = "$Dir\$_"
						Get-ChildItem "$parent" | ForEach-Object { Move-Item "$parent\$_" "$Dir" -Force }
						Remove-Item $parent -Force
					}
				}
				Get-ChildItem $Dir -File -Recurse | Unblock-File
			}
		}
		catch {
			# "'$URI' '$Path' '$Dir' '$FN' '$Archive' $_" | Out-File "$FN.txt"
		}
		finally {
			if ($req -is [IDisposable]) { $req.Dispose(); $req = $null; }
		}
	}
}