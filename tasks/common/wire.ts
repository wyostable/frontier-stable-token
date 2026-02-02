import 'dotenv/config'

import { BasePath, Fireblocks } from '@fireblocks/ts-sdk'
import { PublicKey } from '@solana/web3.js'
import { subtask, task } from 'hardhat/config'

import { firstFactory } from '@layerzerolabs/devtools'
import { SUBTASK_LZ_SIGN_AND_SEND, types as devtoolsTypes } from '@layerzerolabs/devtools-evm-hardhat'
import { setTransactionSizeBuffer } from '@layerzerolabs/devtools-solana'
import { type LogLevel, createLogger } from '@layerzerolabs/io-devtools'
import { ChainType, endpointIdToChainType } from '@layerzerolabs/lz-definitions'
import { type IOApp, type OAppConfigurator, type OAppOmniGraph, configureOwnable } from '@layerzerolabs/ua-devtools'
import {
    SUBTASK_LZ_OAPP_WIRE_CONFIGURE,
    type SubtaskConfigureTaskArgs,
    TASK_LZ_OAPP_WIRE,
    TASK_LZ_OWNABLE_TRANSFER_OWNERSHIP,
} from '@layerzerolabs/ua-devtools-evm-hardhat'

import { getSolanaDeployment, useWeb3Js } from '../solana'
import { findSolanaEndpointIdInGraph } from '../solana/utils'

import { publicKey as publicKeyType } from './types'
import {
    DebugLogger,
    KnownErrors,
    createFireblocksSolanaSignerFactory,
    createSdkFactory,
    createSolanaConnectionFactory,
    createSolanaSignerFactory,
    getSolanaUlnConfigPDAs,
} from './utils'

import type { SignAndSendTaskArgs } from '@layerzerolabs/devtools-evm-hardhat/tasks'

/**
 * Additional CLI arguments for our custom wire task
 */
interface Args {
    logLevel: LogLevel
    multisigKey?: PublicKey
    isSolanaInitConfig: boolean // For internal use only. This helps us to control which code runs depdending on whether the task ran is wire or init-config
    oappConfig: string
    internalConfigurator?: OAppConfigurator
    fireblocksApiKey?: string
    fireblocksPrivateKey?: string
    fireblocksVaultAccountId?: string
    fireblocksAssetId?: string
    payerAddress?: string
}

/**
 * We extend the default wiring task to add functionality required by Solana
 */
task(TASK_LZ_OAPP_WIRE)
    .addParam('multisigKey', 'The MultiSig key', undefined, publicKeyType, true)
    // We use this argument to get around the fact that we want to both override the task action for the wiring task
    // and wrap this task with custom configurators
    //
    // By default, this argument will be left empty and the default OApp configurator will be used.
    // The tasks that are using custom configurators will override this argument with the configurator of their choice
    .addParam('internalConfigurator', 'FOR INTERNAL USE ONLY', undefined, devtoolsTypes.fn, true)
    .addParam('isSolanaInitConfig', 'FOR INTERNAL USE ONLY', undefined, devtoolsTypes.boolean, true)
    .addOptionalParam('fireblocksApiKey', 'Fireblocks API key', process.env.FIREBLOCKS_API_KEY, devtoolsTypes.string)
    .addOptionalParam(
        'fireblocksPrivateKey',
        'Fireblocks private key',
        process.env.FIREBLOCKS_PRIVATE_KEY,
        devtoolsTypes.string
    )
    .addOptionalParam(
        'fireblocksVaultAccountId',
        'Fireblocks vault account ID',
        process.env.SOLANA_FIREBLOCKS_VAULT_ACCOUNT_IDS,
        devtoolsTypes.string
    )
    .addOptionalParam(
        'fireblocksAssetId',
        'Fireblocks asset ID (default: SOL_TEST for testnet, SOL for mainnet)',
        process.env.SOLANA_FIREBLOCKS_ASSET_ID || 'SOL_TEST',
        devtoolsTypes.string
    )
    .addOptionalParam(
        'payerAddress',
        'Payer address for Solana transactions',
        process.env.SOLANA_PAYER_ADDRESS,
        devtoolsTypes.string
    )
    .setAction(async (args: Args, hre, runSuper) => {
        const logger = createLogger(args.logLevel)

        //
        //
        // ENVIRONMENT SETUP
        //
        //

        // The Solana transaction size estimation algorithm is not very accurate, so we increase its tolerance by 192 bytes
        setTransactionSizeBuffer(192)

        //
        //
        // USER INPUT
        //
        //

        const useFireblocksForSolana =
            args.fireblocksApiKey && args.fireblocksPrivateKey && args.fireblocksVaultAccountId && args.payerAddress

        let keypair: Awaited<ReturnType<typeof useWeb3Js>>['web3JsKeypair'] | undefined,
            userAccount: PublicKey,
            fireblocks: Fireblocks | undefined,
            fireblocksConfig: {
                fireblocks?: Fireblocks
                vaultAccountId?: string
                assetId?: string
                payer?: PublicKey
            } = {}

        if (useFireblocksForSolana) {
            logger.info('Using Fireblocks for Solana transaction signing')

            const apiKey = args.fireblocksApiKey
            const privateKey = args.fireblocksPrivateKey
            const vaultAccountId = args.fireblocksVaultAccountId
            const payerAddress = args.payerAddress

            if (!apiKey || !privateKey || !vaultAccountId || !payerAddress) {
                throw new Error(
                    'Missing required Fireblocks configuration. Please set environment variables: FIREBLOCKS_API_KEY, FIREBLOCKS_PRIVATE_KEY, SOLANA_FIREBLOCKS_VAULT_ACCOUNT_IDS, and SOLANA_PAYER_ADDRESS.'
                )
            }

            fireblocks = new Fireblocks({
                apiKey: apiKey,
                basePath: BasePath.US,
                secretKey: privateKey,
            })

            userAccount = new PublicKey(payerAddress)

            fireblocksConfig = {
                fireblocks,
                vaultAccountId,
                assetId: args.fireblocksAssetId,
                payer: userAccount,
            }

            logger.info(`Fireblocks configuration loaded: VaultId=${vaultAccountId}, Payer=${userAccount.toBase58()}`)
        } else {
            logger.info('Using local keypair for Solana transaction signing')

            // construct the user's keypair via the SOLANA_PRIVATE_KEY env var
            keypair = (await useWeb3Js()).web3JsKeypair
            userAccount = keypair.publicKey
        }

        const solanaEid = await findSolanaEndpointIdInGraph(hre, args.oappConfig)
        const solanaDeployment = getSolanaDeployment(solanaEid)

        // Then we grab the programId from the args
        const programId = new PublicKey(solanaDeployment.programId)

        // TODO: refactor to instead use a function such as verifySolanaDeployment that also checks for oftStore key
        if (!programId) {
            logger.error('Missing programId in solana deployment')
            return
        }

        const configurator = args.internalConfigurator

        //
        //
        // TOOLING SETUP
        //
        //

        // We'll need a connection factory to be able to query the Solana network
        //
        // If you haven't set RPC_URL_SOLANA and/or RPC_URL_SOLANA_TESTNET environment variables,
        // the factory will use the default public RPC URLs
        const connectionFactory = createSolanaConnectionFactory()

        // We'll need SDKs to be able to use devtools
        const sdkFactory = createSdkFactory(userAccount, programId, connectionFactory)

        // We'll also need a signer factory - use Fireblocks or local keypair based on configuration
        const solanaSignerFactory = useFireblocksForSolana
            ? createFireblocksSolanaSignerFactory(
                  fireblocksConfig.fireblocks as Fireblocks,
                  fireblocksConfig.vaultAccountId as string,
                  fireblocksConfig.payer as PublicKey,
                  connectionFactory,
                  fireblocksConfig.assetId as string
              )
            : createSolanaSignerFactory(
                  keypair as Awaited<ReturnType<typeof useWeb3Js>>['web3JsKeypair'],
                  connectionFactory,
                  args.multisigKey
              )

        //
        //
        // SUBTASK OVERRIDES
        //
        //

        // We'll need to override the default implementation of the configure subtask
        // (responsible for collecting the on-chain configuration of the contracts
        // and coming up with the transactions that need to be sent to the network)
        //
        // The only thing we are overriding is the sdkFactory parameter - we supply the SDK factory we created above
        subtask(
            SUBTASK_LZ_OAPP_WIRE_CONFIGURE,
            'Configure OFT',
            async (subtaskArgs: SubtaskConfigureTaskArgs<OAppOmniGraph, IOApp>, _hre, runSuper) => {
                // start of pre-wiring checks. we only do this when the current task is wire. if the current task is init-config, we shouldn't run this.
                if (!args.isSolanaInitConfig) {
                    logger.debug('Running pre-wiring checks...')
                    const { graph } = subtaskArgs
                    for (const connection of graph.connections) {
                        // check if from Solana Endpoint
                        if (endpointIdToChainType(connection.vector.from.eid) === ChainType.SOLANA) {
                            if (connection.config?.sendLibrary) {
                                // Check if this is BlockedMessageLib - if so, skip the config checks
                                const BLOCKED_MESSAGE_LIB_SOLANA_MAINNET =
                                    '2XrYqmhBMPJgDsb4SVbjV1PnJBprurd5bzRCkHwiFCJB'
                                const BLOCKED_MESSAGE_LIB_SOLANA_TESTNET =
                                    '2XrYqmhBMPJgDsb4SVbjV1PnJBprurd5bzRCkHwiFCJB'
                                const sendLibraryAddress = connection.config.sendLibrary

                                // Check if this is a BlockedMessageLib address for either mainnet or testnet
                                if (
                                    sendLibraryAddress === BLOCKED_MESSAGE_LIB_SOLANA_MAINNET ||
                                    sendLibraryAddress === BLOCKED_MESSAGE_LIB_SOLANA_TESTNET
                                ) {
                                    logger.verbose(
                                        `Skipping ULN config checks for BlockedMessageLib on ${connection.vector.from.eid}`
                                    )
                                    continue
                                }

                                logger.verbose(`Send library found. Checking if ULN configs have been initialized...`)

                                try {
                                    // Use the SDK to check if configs exist
                                    const [sendConfig, receiveConfig] = await getSolanaUlnConfigPDAs(
                                        connection.vector.to.eid,
                                        await connectionFactory(connection.vector.from.eid),
                                        new PublicKey(connection.config.sendLibrary),
                                        new PublicKey(connection.vector.from.address)
                                    )

                                    logger.verbose(
                                        `ULN configs checked successfully for ${connection.vector.from.eid} -> ${connection.vector.to.eid}`
                                    )
                                } catch (error) {
                                    logger.verbose(`Error checking ULN configs: ${error}`)
                                    DebugLogger.printErrorAndFixSuggestion(
                                        KnownErrors.ULN_INIT_CONFIG_SKIPPED,
                                        `ULN configs on ${connection.vector.from.eid} not initialized for remote ${connection.vector.to.eid}.`
                                    )
                                    throw new Error('ULN configs not initialized. Please run init-config task first.')
                                }
                            } else {
                                logger.debug(
                                    `No sendLibrary found in connection config for ${connection.vector.from.eid} -> ${connection.vector.to.eid}`
                                )
                            }
                        }
                    }
                    // end of pre-wiring checks
                }

                return runSuper({
                    ...subtaskArgs,
                    configurator: configurator ?? subtaskArgs.configurator,
                    sdkFactory,
                })
            }
        )

        // We'll also need to override the default implementation of the signAndSend subtask
        // (responsible for sending transactions to the network and waiting for confirmations)
        //
        // In this subtask we need to override the createSigner function so that it uses the Solana
        // signer for all Solana transactions
        subtask(SUBTASK_LZ_SIGN_AND_SEND, 'Sign OFT transactions', (args: SignAndSendTaskArgs, _hre, runSuper) =>
            runSuper({
                ...args,
                createSigner: firstFactory(solanaSignerFactory, args.createSigner),
            })
        )

        return runSuper(args)
    })

// We'll change the default ownership transfer task to use our wire implementation
//
// The reason for this is the fact that the ownership transfer task has a deficiency
// and that is the fact that it does not support a custom SDK factory as of yet
//
// The two tasks are identical and the only drawback of this approach is the fact
// that the logs will say "Wiring OApp" instead of "Transferring ownership"
task(TASK_LZ_OWNABLE_TRANSFER_OWNERSHIP)
    .addParam('multisigKey', 'The MultiSig key', undefined, publicKeyType, true)
    .addOptionalParam('fireblocksApiKey', 'Fireblocks API key', process.env.FIREBLOCKS_API_KEY, devtoolsTypes.string)
    .addOptionalParam(
        'fireblocksPrivateKey',
        'Fireblocks private key',
        process.env.FIREBLOCKS_PRIVATE_KEY,
        devtoolsTypes.string
    )
    .addOptionalParam(
        'fireblocksVaultAccountId',
        'Fireblocks vault account ID',
        process.env.SOLANA_FIREBLOCKS_VAULT_ACCOUNT_IDS,
        devtoolsTypes.string
    )
    .addOptionalParam(
        'fireblocksAssetId',
        'Fireblocks asset ID (default: SOL_TEST for testnet, SOL for mainnet)',
        process.env.SOLANA_FIREBLOCKS_ASSET_ID || 'SOL_TEST',
        devtoolsTypes.string
    )
    .addOptionalParam(
        'payerAddress',
        'Payer address for Solana transactions',
        process.env.SOLANA_PAYER_ADDRESS,
        devtoolsTypes.string
    )
    .setAction(async (args: Args, hre) => {
        return hre.run(TASK_LZ_OAPP_WIRE, { ...args, internalConfigurator: configureOwnable })
    })
