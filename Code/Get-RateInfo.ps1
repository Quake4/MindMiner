function Get-RateInfo {
	$json = Get-UrlAsJson "https://api.coinbase.com/v2/exchange-rates?currency=BTC"

	$result = [hashtable]@{}
	$Config.Currencies | ForEach-Object {
		if ([string]::Equals($_, "BTC", [StringComparison]::InvariantCultureIgnoreCase)) {
			$result.Add("BTC", [decimal]1)
		}
		elseif ([string]::Equals($_, "mBTC", [StringComparison]::InvariantCultureIgnoreCase)) {
			$result.Add("mBTC", [decimal]1000)
		}
		elseif ($json.data.rates.$_) {
			$result.Add($_, [decimal]$json.data.rates."$_")
		}
	}
	$result
}