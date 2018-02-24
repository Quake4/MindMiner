# Сonfiguration of MindMiner

## Pools
Pools configuration placed in Pools folder and named as pool name and config extension.
Look like this "PoolName.config.txt".

Any pool has this config:
```json
{
    "AverageProfit":  "1 hour 30 min",
    "Enabled":  false
}
```

* **Enabled** - enable or disable pool for mine.
* **AverageProfit** - averages a profit on the coins at the specified time interval.
* ***APiKey*** - key for get balance on MiningPoolHub. See "Edit Account" section and "API KEY" value in MPH account.
