<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/LayerZero_Logo_White.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://layerzero.network" style="color: #a77dff">Homepage</a> | <a href="https://docs.layerzero.network/" style="color: #a77dff">Docs</a> | <a href="https://layerzero.network/developers" style="color: #a77dff">Developers</a>
</p>

<h1 align="center">Wyoming OFT project</h1>

## Overview

This project introduces two tokens: a base token (`FRNT`) and a yield-bearing token (`wFRNT`), implemented with an ERC-4626 vault. Both token contracts extend ERC-20F, a Fireblocks standard built on top of OpenZeppelin’s `ERC20Upgradeable` contract.

⚠️ Check more details on Fireblocks' contracts [here](./contracts/fireblocks/README.md) ⚠️

On the hub chain, the `FrontierVault` - an ERC-4626-compliant vault - manages the yield-bearing token. On the spoke chains, a standard ERC-20F implementation of `wFRNT` is deployed.

A `FrontierAccessRegistry` contract governs wallet permissions across both tokens. This contract is queried before any transfer, mint, or receive operation and may delegate additional checks to the Chainalysis sanctions list to enforce compliance.

Cross-chain token movement is enabled through adapters:

- For the yield-bearing token (`wFRNT`), an OFT adapter (`FrontierOFTAdapter`) is deployed on the hub chain. It uses a lock/unlock mechanism to preserve the vault's total supply-based yield calculations. Burning tokens during cross-chain transfers is not allowed to maintain consistency in yield computation.
- For the base token (`FRNT`) and the spoke chain versions of `wFRNT`, mint/burn adapters are used: `FRNTMintAndBurnAdapter` and `wFRNTMintAndBurnAdapter` (both inherit `FrontierOFTAdapterMintAndBurn`).

Scope:

```bash
contracts
├ FrontierERC20F.sol
├ FrontierOFTAdapter.sol
├ FrontierOFTAdapterMintAndBurn.sol
└ FrontierVault.sol
```

## Deploying the contracts

The deployment order is really important:

1. Deploy `DenyList` on all chains of the mesh;
2. Deploy `FrontierERC20F` on all chains and set the deny list address (`FrontierERC20F.accessRegistryUpdate(...)`) for both base and yield bearing tokens;
3. Deploy `FrontierVault` on the hub chain and set the deny list address (`FrontierVault.accessRegistryUpdate(...)`);
4. Deploy `FrontierOFTAdapterMintAndBurn` on all chains setting the address of the underlying token as token and `minterBurner`;
5. Grant minter and burner role to the adapter on the token contract on all chains;
6. Deploy `FrontierOFTAdapter` on the hub chain, setting as `FrontierVault` token;

## Using the contracts

Some functions have specific access controls:

- Mint (`mint(...)`): only minter role and only to active wallets
- Burn (`burn(...)`): only burner role
- Transfer (`transfer(...)`/`transferFrom(...)`): only from and to active wallets
- Add/remove wallet to/from deny list (`accessListAdd(...)`/`accessListRemove(...)`): only access list admin role
- Add deny list registry to the token contract (`accessRegistryUpdate(...)`): only contract admin role
- Pause/unpause (`pause(...)`/`unpause(...)`): only pauser role
- Upgrade (`upgradeToAndCall(...)`): only upgrader role
- Salvage tokens (`salvageERC20(...)`/`salvageGas(...)`): only salvage role

“Active wallets” means wallets that are not in the deny list.

You can call `FrontierOFTAdapterMintAndBurn.send(...)` as you would call a regular OFT contract.

In the case of cross-chain transfer where the recipient address on the destination chain is frozen, the transfer will go through even though the wallet is frozen (by calling `mintToFrozenWallet` function on MABA and `transferToFrozenWallet` on the OFT adapter). This is done so that the destination transaction doesn’t revert. The recipient won’t be able to use the received tokens anyway, since the wallet is frozen and it can’t transfer the tokens, even cross-chain.


## Solana Program Verification

1. `cargo install solana-verify --git https://github.com/Ellipsis-Labs/solana-verifiable-build`
2. `solana-verify verify-from-repo -um --program-id 3eZMk1HzqcbgBPjjyz9Hkd2QPxLDXCiVBx2syKUYT9oC <repo url> --library-name oft -- --config env.OFT_ID=\'3eZMk1HzqcbgBPjjyz9Hkd2QPxLDXCiVBx2syKUYT9oC\'`

To see the verification status from the api, please run: `curl https://verify.osec.io/status/3eZMk1HzqcbgBPjjyz9Hkd2QPxLDXCiVBx2syKUYT9oC | jq`

If there are any failures, ensure the local and on chain program hashes match:
1. `RUSTUP_TOOLCHAIN=nightly-2025-05-01 anchor build -v -e OFT_ID=3eZMk1HzqcbgBPjjyz9Hkd2QPxLDXCiVBx2syKUYT9oC`
2. `solana-verify get-executable-hash ./target/verifiable/oft.so`
3. `solana-verify get-program-hash --url "<mainnet rpc url>" 3eZMk1HzqcbgBPjjyz9Hkd2QPxLDXCiVBx2syKUYT9oC`

The output from steps 2 and 3 should match.

## Failures

### Not Enough Message Value for A -> B Query

The adapter is not given enough `msg.value` to pay for the transferring tokens. This will hard revert on the source chain with error `InsufficientMessageValue`.

### `to` or `from` addresses are in the deny list (token transfer)

If the `to` or `from` address is in the deny list, the transaction will revert

### `from` addresses are in the deny list (token cross-chain transfer)

If the `from` address is in the deny list, the transaction will revert

### Caller is not allowed

If a caller address calls a function with role-base access control and does not have that specific role granted to itself, the transaction will revert.


## Configure contracts through Fireblocks

1. Populate .env file with 

```bash
RPC_URL_SOLANA=
RPC_URL_SOLANA_TESTNET=
FIREBLOCKS_API_KEY=
FIREBLOCKS_PRIVATE_KEY=
FIREBLOCKS_VAULT_ACCOUNT_IDS=
SOLANA_FIREBLOCKS_ASSET_ID= # SOL_TEST or SOL
SOLANA_PAYER_ADDRESS=
```

2. Update `hardhat.config.ts` with the new chain if needed (see how it is done for existing chains)

3. Update `consts/wire.ts` with DVNs and enforced options as needed (see how it is done for existing chains)

      a. Make sure to update the `getRequiredDVNs` and `getOptionalDVNs` functions if introducing new dvns
  

4. Update the `layerzero-mainnet.config.ts` with the new chain (see how it is done for existing chains)

### Configure existing contracts
1. Set the evm vault account id within the `FIREBLOCKS_VAULT_ACCOUNT_IDS` environment variable then run `npx hardhat lz:oapp:wire --oapp-config layerzero-mainnet.config.ts --skip-connections-from-eids 30168` 
2.  Set the solana vault account id within the `FIREBLOCKS_VAULT_ACCOUNT_IDS` environment variable then run `npx hardhat lz:oft:solana:init-config --oapp-config layerzero-mainnet.config.ts`
3. Finally, run `npx hardhat lz:oapp:wire --oapp-config layerzero-mainnet.config.ts` to complete wiring