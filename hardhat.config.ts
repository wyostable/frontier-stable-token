// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import '@openzeppelin/hardhat-upgrades'
import 'hardhat-deploy'
import 'hardhat-deploy-ethers'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'

import { ApiBaseUrl } from '@fireblocks/fireblocks-web3-provider'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import '@fireblocks/hardhat-fireblocks'

import './tasks/index'

/**
 * Uncomment the accounts logic below and within each network if you want to use direct environment configuration
 * (i.e transactions will not be sent through Fireblocks)
 */
// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
// const MNEMONIC = process.env.MNEMONIC

// // If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
// const PRIVATE_KEY = process.env.PRIVATE_KEY

// const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
//     ? { mnemonic: MNEMONIC }
//     : PRIVATE_KEY
//       ? [PRIVATE_KEY, PRIVATE_KEY, PRIVATE_KEY]
//       : undefined

// if (accounts == null) {
//     console.warn(
//         'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
//     )
// }

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
        tests: 'test/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 20000,
                    },
                },
            },
        ],
    },
    networks: {
        // Testnet networks
        'arb-sepolia': {
            eid: EndpointId.ARBSEP_V2_TESTNET,
            url: process.env.RPC_URL_ARBSEP_TESTNET || 'https://sepolia-rollup.arbitrum.io/rpc',
            chainId: 421614,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'avalanche-fuji': {
            eid: EndpointId.AVALANCHE_V2_TESTNET,
            url: process.env.RPC_URL_AVALANCHE_FUJI_TESTNET || 'https://api.avax-test.network/ext/bc/C/rpc',
            chainId: 43113,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'base-sepolia': {
            eid: EndpointId.BASESEP_V2_TESTNET,
            url: process.env.RPC_URL_BASESEP_TESTNET || 'https://base-sepolia.api.onfinality.io/public',
            chainId: 84532,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'eth-sepolia': {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: process.env.RPC_URL_ETHSEP_TESTNET || 'https://ethereum-sepolia-rpc.publicnode.com',
            chainId: 11155111,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'opt-sepolia': {
            eid: EndpointId.OPTSEP_V2_TESTNET,
            url: process.env.RPC_URL_OPTSEP_TESTNET || 'https://sepolia.optimism.io',
            chainId: 11155420,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'polygon-amoy': {
            eid: EndpointId.AMOY_V2_TESTNET,
            url: process.env.RPC_URL_POLYGON_AMOY_TESTNET || 'https://rpc-amoy.polygon.technology/',
            chainId: 80002,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        'hedera-testnet': {
            eid: EndpointId.HEDERA_V2_TESTNET,
            url: process.env.RPC_URL_HEDERA_TESTNET || 'https://testnet.hashio.io/api',
            chainId: 296,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },

        // Mainnet networks
        arbitrum: {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            url: process.env.RPC_URL_ARBITRUM_MAINNET || 'https://arb1.arbitrum.io/rpc',
            chainId: 42161,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        avalanche: {
            eid: EndpointId.AVALANCHE_V2_MAINNET,
            url: process.env.RPC_URL_AVALANCHE_MAINNET || 'https://api.avax.network/ext/bc/C/rpc',
            chainId: 43114,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        base: {
            eid: EndpointId.BASE_V2_MAINNET,
            url: process.env.RPC_URL_BASE_MAINNET || 'https://mainnet.base.org',
            chainId: 8453,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        ethereum: {
            eid: EndpointId.ETHEREUM_V2_MAINNET,
            url: process.env.RPC_URL_ETHEREUM_MAINNET || 'https://ethereum-rpc.publicnode.com',
            chainId: 1,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        optimism: {
            eid: EndpointId.OPTIMISM_V2_MAINNET,
            url: process.env.RPC_URL_OPTIMISM_MAINNET || 'https://mainnet.optimism.io',
            chainId: 10,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },
        polygon: {
            eid: EndpointId.POLYGON_V2_MAINNET,
            url: process.env.RPC_URL_POLYGON_MAINNET || 'https://polygon-rpc.com',
            chainId: 137,
            fireblocks: {
                privateKey: process.env.FIREBLOCKS_PRIVATE_KEY || '',
                apiKey: process.env.FIREBLOCKS_API_KEY || '',
                vaultAccountIds: process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS
                    ? process.env.EVM_FIREBLOCKS_VAULT_ACCOUNT_IDS.split(',')
                    : [],
                apiBaseUrl: ApiBaseUrl.Production,
            },
            // accounts,
        },

        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
        minterAndBurner: {
            default: 1,
        },
        complianceManager: {
            default: 2,
        },
    },
}

export default config
