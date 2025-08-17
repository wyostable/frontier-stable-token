# Why use Fireblocks' contract this way?

Two main reasons:

1. Fireblocks do NOT provide these contracts as a `npm` package or `forge` submodule
2. These contracts use OpenZeppelin V4 and LayerZero uses OpenZeppelin V5, which messes up the imports. Because of that, both imports were seperated and in `package.json` are named as follows:

```json
{
    "@openzeppelin/contracts": "^5.0.2",
    "@openzeppelin/contracts-upgradeable": "^5.0.2",
    "@openzeppelin/contracts-upgradeable-v4": "npm:@openzeppelin/contracts-upgradeable@4.9.3",
    "@openzeppelin/contracts-v4": "npm:@openzeppelin/contracts@4.9.3",
}
```