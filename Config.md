# Сonfiguration of MindMiner
Any configuration stored in json format.

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

* **Enabled** [bool] (true|false) - enable or disable pool for mine.
* **AverageProfit** [string] - averages a profit on the coins at the specified [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md).
* ***APiKey*** [string] - key for get balance on MiningPoolHub. See "Edit Account" section and "API KEY" value in MPH account.

Pools config read on each loop. You may change configuration at any time and it will be applied on the next loop.

## Miners
Miners configuration placed in Miners folder and named as miner name and config extension.
Look like this "MinerName.config.txt".

Miners config read on each loop. You may change configuration at any time and it will be applied on the next loop.

