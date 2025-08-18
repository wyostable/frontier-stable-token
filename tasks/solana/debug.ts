import { fetchMint } from '@metaplex-foundation/mpl-toolbox'
import { publicKey, unwrapOption } from '@metaplex-foundation/umi'
import { toWeb3JsPublicKey } from '@metaplex-foundation/umi-web3js-adapters'
import { Keypair, PublicKey } from '@solana/web3.js'
import { task } from 'hardhat/config'

import { OmniPoint, denormalizePeer } from '@layerzerolabs/devtools'
import { types } from '@layerzerolabs/devtools-evm-hardhat'
import { EndpointId, getNetworkForChainId } from '@layerzerolabs/lz-definitions'
import { EndpointPDADeriver, EndpointProgram } from '@layerzerolabs/lz-solana-sdk-v2'
import { OftPDA, oft } from '@layerzerolabs/oft-v2-solana-sdk'
import { EndpointV2 } from '@layerzerolabs/protocol-devtools-solana'

import { getSolanaReceiveConfig, getSolanaSendConfig } from '../common/taskHelper'
import { DebugLogger, createSolanaConnectionFactory, decodeLzReceiveOptions, uint8ArrayToHex } from '../common/utils'

import { deriveConnection, getSolanaDeployment } from './index'

const DEBUG_ACTIONS = {
    OFT_STORE: 'oft-store',
    GET_ADMIN: 'admin',
    GET_DELEGATE: 'delegate',
    GET_PROGRAM: 'program',
    CHECKS: 'checks',
    GET_TOKEN: 'token',
    GET_PEERS: 'peers',
}

/**
 * Get the OFTStore account from the task arguments, the deployment file, or throw an error.
 * @param {EndpointId} eid
 * @param {string} oftStore
 */
const getOftStore = (eid: EndpointId, oftStore?: string) => publicKey(oftStore ?? getSolanaDeployment(eid).oftStore)

type DebugTaskArgs = {
    eid: EndpointId
    oftStore?: string
    endpoint: string
    dstEids: EndpointId[]
    action?: string
}

task('lz:oft:solana:debug', 'Manages OFTStore and OAppRegistry information')
    .addParam(
        'eid',
        'Solana mainnet (30168) or testnet (40168).  Defaults to mainnet.',
        EndpointId.SOLANA_V2_MAINNET,
        types.eid
    )
    .addParam(
        'oftStore',
        'The OFTStore public key. Derived from deployments if not provided.',
        undefined,
        types.string,
        true
    )
    .addParam('endpoint', 'The Endpoint public key', EndpointProgram.PROGRAM_ID.toBase58(), types.string)
    .addOptionalParam('dstEids', 'Destination eids to check (comma-separated list)', [], types.csv)
    .addOptionalParam(
        'action',
        `The action to perform: ${Object.keys(DEBUG_ACTIONS).join(', ')} (defaults to all)`,
        undefined,
        types.string
    )
    .setAction(async (taskArgs: DebugTaskArgs) => {
        const { eid, oftStore: oftStoreArg, endpoint, dstEids, action } = taskArgs
        const { umi, connection } = await deriveConnection(eid, true)
        const oftStore = getOftStore(eid, oftStoreArg)

        let oftStoreInfo
        try {
            oftStoreInfo = await oft.accounts.fetchOFTStore(umi, oftStore)
        } catch (e) {
            console.error(`Failed to fetch OFTStore at ${oftStore.toString()}:`, e)
            return
        }

        const mintAccount = await fetchMint(umi, publicKey(oftStoreInfo.tokenMint))

        const epDeriver = new EndpointPDADeriver(new PublicKey(endpoint))
        const [oAppRegistry] = epDeriver.oappRegistry(toWeb3JsPublicKey(oftStore))
        const oAppRegistryInfo = await EndpointProgram.accounts.OAppRegistry.fromAccountAddress(
            connection,
            oAppRegistry
        )

        if (!oAppRegistryInfo) {
            console.warn('OAppRegistry info not found.')
            return
        }

        const oftDeriver = new OftPDA(oftStoreInfo.header.owner)

        const printOftStore = async () => {
            DebugLogger.header('OFT Store Information')
            DebugLogger.keyValue('Owner', oftStoreInfo.header.owner)
            DebugLogger.keyValue('OFT Type', oft.types.OFTType[oftStoreInfo.oftType])
            DebugLogger.keyValue('Admin', oftStoreInfo.admin)
            DebugLogger.keyValue('Token Mint', oftStoreInfo.tokenMint)
            DebugLogger.keyValue('Token Escrow', oftStoreInfo.tokenEscrow)
            DebugLogger.keyValue('Endpoint Program', oftStoreInfo.endpointProgram)
            DebugLogger.keyValue('Paused', oftStoreInfo.paused)
            DebugLogger.keyValue(
                'Pauser',
                oftStoreInfo.pauser?.__option === 'Some' ? oftStoreInfo.pauser.value : 'Not set'
            )
            DebugLogger.keyValue(
                'Unpauser',
                oftStoreInfo.unpauser?.__option === 'Some' ? oftStoreInfo.unpauser.value : 'Not set'
            )
            DebugLogger.keyValue('Default Fee (BPS)', oftStoreInfo.defaultFeeBps)
            DebugLogger.separator()
        }

        const printAdmin = async () => {
            const admin = oftStoreInfo.admin
            DebugLogger.keyValue('Admin', admin)
        }

        const printDelegate = async () => {
            const delegate = oAppRegistryInfo?.delegate?.toBase58()
            DebugLogger.header('OApp Registry Information')
            DebugLogger.keyValue('Delegate', delegate)
            DebugLogger.separator()
        }

        const printProgramAuthority = async () => {
            DebugLogger.header('Program Authority Information')

            const targetProgramId = new PublicKey(oftStoreInfo.header.owner)
            const programAccount = await connection.getAccountInfo(targetProgramId)
            if (!programAccount?.data) {
                DebugLogger.keyValue('Program ID', targetProgramId.toBase58())
                DebugLogger.keyValue('Upgrade Authority', 'Unable to fetch program account')
                DebugLogger.separator()
                return
            }
            const programDataAddress = new PublicKey(programAccount.data.slice(4, 36))
            const programDataAccount = await connection.getAccountInfo(programDataAddress)

            // BPF Loader Upgradeable program data structure:
            // Bytes 0-3: Program data discriminator (should be 3)
            // Bytes 4-11: Slot (u64)
            // Byte 12: Option discriminant (0 = None, 1 = Some)
            // Bytes 13-44: Authority (32 bytes, if option = 1)
            DebugLogger.keyValue('Program ID', targetProgramId.toBase58())

            const hasAuthority = programDataAccount?.data.readUInt8(12) === 1
            if (hasAuthority) {
                const authority = new PublicKey(programDataAccount?.data.slice(13, 45))
                DebugLogger.keyValue('Upgrade Authority', authority.toBase58())
            } else {
                DebugLogger.keyValue('Upgrade Authority', 'None (immutable)')
            }

            DebugLogger.separator()
        }

        const printToken = async () => {
            DebugLogger.header('Token Information')
            DebugLogger.keyValue('Mint Authority', unwrapOption(mintAccount.mintAuthority))
            DebugLogger.keyValue(
                'Freeze Authority',
                unwrapOption(mintAccount.freezeAuthority, () => 'None')
            )

            // Check for Token 2022 pause authority extension
            try {
                const mintInfo = await connection.getAccountInfo(toWeb3JsPublicKey(publicKey(oftStoreInfo.tokenMint)))
                if (mintInfo?.data) {
                    const { ExtensionType, getExtensionData, unpackMint } = await import('@solana/spl-token')

                    try {
                        // Check if this is a Token 2022 mint with extensions
                        if (mintInfo.data.length > 82) {
                            // Parse the mint to get TLV data
                            const mint = unpackMint(
                                toWeb3JsPublicKey(publicKey(oftStoreInfo.tokenMint)),
                                mintInfo,
                                mintInfo.owner
                            )

                            // Get pause config extension data
                            const pauseData = getExtensionData(ExtensionType.PausableConfig, mint.tlvData)
                            if (pauseData && pauseData.length >= 32) {
                                // First 32 bytes should be the pause authority pubkey
                                const pauseAuthority = new PublicKey(pauseData.slice(0, 32))
                                DebugLogger.keyValue('Pause Authority', pauseAuthority.toBase58())
                            } else {
                                DebugLogger.keyValue('Pause Authority', 'Not set (no pausable config)')
                            }

                            // Get metadata pointer extension data
                            const metadataPointerData = getExtensionData(ExtensionType.MetadataPointer, mint.tlvData)
                            if (metadataPointerData && metadataPointerData.length >= 64) {
                                // First 32 bytes: authority, next 32 bytes: metadata address
                                const metadataAuthority = new PublicKey(metadataPointerData.slice(0, 32))
                                const metadataAddress = new PublicKey(metadataPointerData.slice(32, 64))
                                DebugLogger.keyValue('Metadata Authority', metadataAuthority.toBase58())
                                DebugLogger.keyValue('Metadata Address', metadataAddress.toBase58())
                            } else {
                                DebugLogger.keyValue('Metadata Authority', 'Not set (no metadata pointer)')
                            }

                            // Get metadata extension data for update authority
                            const metadataData = getExtensionData(ExtensionType.TokenMetadata, mint.tlvData)
                            if (metadataData && metadataData.length >= 32) {
                                // First 32 bytes should be the update authority
                                const updateAuthority = new PublicKey(metadataData.slice(0, 32))
                                DebugLogger.keyValue('Update Authority', updateAuthority.toBase58())

                                // Try to extract name and symbol (this is more complex due to variable length)
                                try {
                                    // Skip update authority (32) + mint (32) = 64 bytes
                                    let offset = 64

                                    // Name length (4 bytes) + name
                                    const nameLength = metadataData.readUInt32LE(offset)
                                    offset += 4
                                    const name = metadataData.slice(offset, offset + nameLength).toString('utf8')
                                    offset += nameLength

                                    // Symbol length (4 bytes) + symbol
                                    const symbolLength = metadataData.readUInt32LE(offset)
                                    offset += 4
                                    const symbol = metadataData.slice(offset, offset + symbolLength).toString('utf8')

                                    DebugLogger.keyValue('Token Name', name)
                                    DebugLogger.keyValue('Token Symbol', symbol)
                                } catch (error) {
                                    DebugLogger.keyValue('Token Name', 'Unable to parse')
                                    DebugLogger.keyValue('Token Symbol', 'Unable to parse')
                                }
                            } else {
                                DebugLogger.keyValue('Update Authority', 'Not set (no token metadata)')
                            }

                            // Get permanent delegate extension data
                            const permanentDelegateData = getExtensionData(
                                ExtensionType.PermanentDelegate,
                                mint.tlvData
                            )
                            if (permanentDelegateData && permanentDelegateData.length >= 32) {
                                // First 32 bytes should be the permanent delegate pubkey
                                const permanentDelegate = new PublicKey(permanentDelegateData.slice(0, 32))
                                DebugLogger.keyValue('Permanent Delegate', permanentDelegate.toBase58())
                            } else {
                                DebugLogger.keyValue('Permanent Delegate', 'Not set (no permanent delegate)')
                            }
                        } else {
                            DebugLogger.keyValue('Pause Authority', 'Not available (standard SPL token)')
                            DebugLogger.keyValue('Permanent Delegate', 'Not available (standard SPL token)')
                        }
                    } catch (extensionError) {
                        DebugLogger.keyValue('Pause Authority', `Error parsing extensions: ${extensionError}`)
                    }
                } else {
                    DebugLogger.keyValue('Pause Authority', 'Unable to fetch mint info')
                }
            } catch (error) {
                DebugLogger.keyValue('Pause Authority', `Error: ${error}`)
            }

            DebugLogger.separator()
        }

        const printChecks = async () => {
            const delegate = oAppRegistryInfo?.delegate?.toBase58()
            const pauser = oftStoreInfo.pauser?.__option === 'Some' ? oftStoreInfo.pauser.value : null
            const unpauser = oftStoreInfo.unpauser?.__option === 'Some' ? oftStoreInfo.unpauser.value : null

            DebugLogger.header('Checks')
            DebugLogger.keyValue('Admin (Owner) same as Delegate', oftStoreInfo.admin === delegate)
            DebugLogger.keyValue('Admin same as Pauser', pauser ? oftStoreInfo.admin === pauser : 'N/A (no pauser set)')
            DebugLogger.keyValue(
                'Admin same as Unpauser',
                unpauser ? oftStoreInfo.admin === unpauser : 'N/A (no unpauser set)'
            )
            DebugLogger.keyValue(
                'Token Mint Authority is OFT Store',
                unwrapOption(mintAccount.mintAuthority) === oftStore
            )
            DebugLogger.separator()
        }

        const printPeerConfigs = async () => {
            const peerConfigs = dstEids.map((dstEid) => {
                const peerConfig = oftDeriver.peer(oftStore, dstEid)
                return publicKey(peerConfig)
            })
            const mockKeypair = new Keypair()
            const point: OmniPoint = {
                eid,
                address: oftStore.toString(),
            }
            const endpointV2Sdk = new EndpointV2(
                await createSolanaConnectionFactory()(eid),
                point,
                mockKeypair.publicKey // doesn't matter as we are not sending transactions
            )

            DebugLogger.header('Peer Configurations')

            const peerConfigInfos = await oft.accounts.safeFetchAllPeerConfig(umi, peerConfigs)
            for (let index = 0; index < dstEids.length; index++) {
                const dstEid = dstEids[index]
                const info = peerConfigInfos[index]
                const network = getNetworkForChainId(dstEid)
                const oAppReceiveConfig = await getSolanaReceiveConfig(endpointV2Sdk, dstEid, oftStore)
                const oAppSendConfig = await getSolanaSendConfig(endpointV2Sdk, dstEid, oftStore)

                // Show the chain info
                DebugLogger.header(`${dstEid} (${network.chainName})`)

                if (info) {
                    // Existing PeerConfig info
                    DebugLogger.keyValue('PeerConfig Account', peerConfigs[index].toString())
                    DebugLogger.keyValue('Peer Address', denormalizePeer(info.peerAddress, dstEid))
                    DebugLogger.keyHeader('Enforced Options')
                    DebugLogger.keyValue(
                        'Send',
                        decodeLzReceiveOptions(uint8ArrayToHex(info.enforcedOptions.send, true)),
                        2
                    )
                    DebugLogger.keyValue(
                        'SendAndCall',
                        decodeLzReceiveOptions(uint8ArrayToHex(info.enforcedOptions.sendAndCall, true)),
                        2
                    )

                    printOAppReceiveConfigs(oAppReceiveConfig, network.chainName)
                    printOAppSendConfigs(oAppSendConfig, network.chainName)
                } else {
                    // No PeerConfig account
                    console.log(`No PeerConfig account found for ${dstEid} (${network.chainName}).`)
                }

                DebugLogger.separator()
            }
        }
        if (action) {
            switch (action) {
                case DEBUG_ACTIONS.OFT_STORE:
                    await printOftStore()
                    break
                case DEBUG_ACTIONS.GET_ADMIN:
                    await printAdmin()
                    break
                case DEBUG_ACTIONS.GET_DELEGATE:
                    await printDelegate()
                    break
                case DEBUG_ACTIONS.GET_PROGRAM:
                    await printProgramAuthority()
                    break
                case DEBUG_ACTIONS.CHECKS:
                    await printChecks()
                    break
                case DEBUG_ACTIONS.GET_TOKEN:
                    await printToken()
                    break
                case DEBUG_ACTIONS.GET_PEERS:
                    await printPeerConfigs()
                    break
                default:
                    console.error(`Invalid action specified. Use any of ${Object.keys(DEBUG_ACTIONS)}.`)
            }
        } else {
            await printOftStore()
            await printDelegate()
            await printProgramAuthority()
            await printToken()
            if (dstEids.length > 0) await printPeerConfigs()
            await printChecks()
        }
    })

function printOAppReceiveConfigs(
    oAppReceiveConfig: Awaited<ReturnType<typeof getSolanaReceiveConfig>>,
    peerChainName: string
) {
    const oAppReceiveConfigIndexesToKeys: Record<number, string> = {
        0: 'receiveLibrary',
        1: 'receiveUlnConfig',
        2: 'receiveLibraryTimeoutConfig',
    }

    if (!oAppReceiveConfig) {
        console.log('No receive configs found.')
        return
    }

    DebugLogger.keyValue(`Receive Configs (${peerChainName} to solana)`, '')
    for (let i = 0; i < oAppReceiveConfig.length; i++) {
        const item = oAppReceiveConfig[i]
        if (typeof item === 'object' && item !== null) {
            // Print each property in the object
            DebugLogger.keyValue(`${oAppReceiveConfigIndexesToKeys[i]}`, '', 2)
            for (const [propKey, propVal] of Object.entries(item)) {
                DebugLogger.keyValue(`${propKey}`, String(propVal), 3)
            }
        } else {
            // Print a primitive (string, number, etc.)
            DebugLogger.keyValue(`${oAppReceiveConfigIndexesToKeys[i]}`, String(item), 2)
        }
    }
}

function printOAppSendConfigs(oAppSendConfig: Awaited<ReturnType<typeof getSolanaSendConfig>>, peerChainName: string) {
    const sendOappConfigIndexesToKeys: Record<number, string> = {
        0: 'sendLibrary',
        1: 'sendUlnConfig',
        2: 'sendExecutorConfig',
    }

    if (!oAppSendConfig) {
        console.log('No send configs found.')
        return
    }

    DebugLogger.keyValue(`Send Configs (solana to ${peerChainName})`, '')
    for (let i = 0; i < oAppSendConfig.length; i++) {
        const item = oAppSendConfig[i]
        if (typeof item === 'object' && item !== null) {
            DebugLogger.keyValue(`${sendOappConfigIndexesToKeys[i]}`, '', 2)
            for (const [propKey, propVal] of Object.entries(item)) {
                DebugLogger.keyValue(`${propKey}`, String(propVal), 3)
            }
        } else {
            DebugLogger.keyValue(`${sendOappConfigIndexesToKeys[i]}`, String(item), 2)
        }
    }
}
