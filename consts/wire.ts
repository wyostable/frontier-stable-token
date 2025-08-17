import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { OAppEnforcedOption } from '@layerzerolabs/toolbox-hardhat'

import { fetchMetadata, getEndpointIdDeployment, isSolanaDeployment } from './utils'

export const DVNS = {
    GOOGLE_CLOUD: {
        [EndpointId.ARBITRUM_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.AVALANCHE_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.BASE_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.ETHEREUM_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.OPTIMISM_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.POLYGON_V2_MAINNET]: '0xd56e4eab23cb81f43168f9f45211eb027b9ac7cc',
        [EndpointId.SOLANA_V2_MAINNET]: 'F7gu9kLcpn4bSTZn183mhn2RXUuMy7zckdxJZdUjuALw',
    } as Partial<Record<EndpointId, string>>,
    LZ_LABS: {
        [EndpointId.ARBITRUM_V2_MAINNET]: '0x2f55c492897526677c5b68fb199ea31e2c126416',
        [EndpointId.AVALANCHE_V2_MAINNET]: '0x962f502a63f5fbeb44dc9ab932122648e8352959',
        [EndpointId.BASE_V2_MAINNET]: '0x9e059a54699a285714207b43b055483e78faac25',
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x589dedbd617e0cbcb916a9223f4d1300c294236b',
        [EndpointId.OPTIMISM_V2_MAINNET]: '0x6a02d83e8d433304bba74ef1c427913958187142',
        [EndpointId.POLYGON_V2_MAINNET]: '0x23de2fe932d9043291f870324b74f820e11dc81a',
        [EndpointId.SOLANA_V2_MAINNET]: '4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb',
    } as Partial<Record<EndpointId, string>>,
    WYOMING: {
        [EndpointId.ARBITRUM_V2_MAINNET]: '0xcb1b1d524d013a32e976a5963bd541c388ec0517',
        [EndpointId.AVALANCHE_V2_MAINNET]: '0xda4428ff0f15b9d92c39ae08c4fc2f1216662c2f',
        [EndpointId.BASE_V2_MAINNET]: '0xf80285efb7518d5c79f4e98e3baa59da5ee79621',
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x6c70db9ce65fa37499c1f1a150a6440fc9c7273a',
        [EndpointId.OPTIMISM_V2_MAINNET]: '0x94ec5934daa761d7597b76fd0fecf8385de143be',
        [EndpointId.POLYGON_V2_MAINNET]: '0xf6cb110b0334825797b9b733060229c68e5d8bef',
        [EndpointId.SOLANA_V2_MAINNET]: '6bdMfqghzhFpMsbrfy6qiyXnGkYGcamn3WYxeKx8Muik',
    } as Partial<Record<EndpointId, string>>,
}

// Define enforced options per specific endpoint ID
export const ENFORCED_OPTIONS: Partial<Record<EndpointId, OAppEnforcedOption[]>> = {
    // Testnet
    [EndpointId.AMOY_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
    [EndpointId.ARBSEP_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
    [EndpointId.AVALANCHE_V2_TESTNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 },
    ],
    [EndpointId.BASESEP_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
    [EndpointId.OPTSEP_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
    [EndpointId.SEPOLIA_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
    [EndpointId.SOLANA_V2_TESTNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 250000, value: 2539280 },
    ],

    // Mainnet
    [EndpointId.ARBITRUM_V2_MAINNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 },
    ],
    [EndpointId.AVALANCHE_V2_MAINNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 },
    ],
    [EndpointId.BASE_V2_MAINNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 }],
    [EndpointId.ETHEREUM_V2_MAINNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 },
    ],
    [EndpointId.OPTIMISM_V2_MAINNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 },
    ],
    [EndpointId.POLYGON_V2_MAINNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 }],
    [EndpointId.SOLANA_V2_MAINNET]: [
        { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 143000, value: 2442960 },
    ],
}

export const MULTISIGS: Partial<Record<EndpointId, string>> = {
    // Mainnet addresses
    [EndpointId.ARBITRUM_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.AVALANCHE_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.BASE_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.ETHEREUM_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.OPTIMISM_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.POLYGON_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.SOLANA_V2_MAINNET]: '3FL7iZaerXVygpPAFtXyxoCGdoUt11eiSBYkko6mMD8x',

    // Testnet addresses
    [EndpointId.AMOY_V2_TESTNET]: 'TODO',
    [EndpointId.ARBSEP_V2_TESTNET]: 'TODO',
    [EndpointId.AVALANCHE_V2_TESTNET]: 'TODO',
    [EndpointId.BASESEP_V2_TESTNET]: 'TODO',
    [EndpointId.OPTSEP_V2_TESTNET]: 'TODO',
    [EndpointId.SEPOLIA_V2_TESTNET]: 'TODO',
    [EndpointId.SOLANA_V2_TESTNET]: 'TODO',
} as const

// Helper functions
export const getRequiredDVNs = (eid: EndpointId): string[] => {
    return [DVNS.WYOMING[eid]].filter(Boolean) as string[]
}

export const getOptionalDVNs = (eid: EndpointId): string[] => {
    return [DVNS.GOOGLE_CLOUD[eid], DVNS.LZ_LABS[eid]].filter(Boolean) as string[]
}

export const getEnforcedOptions = (eid: EndpointId): OAppEnforcedOption[] => {
    return ENFORCED_OPTIONS[eid] ?? [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 80000, value: 0 }]
}

export const getMultisigAddress = (eid: EndpointId): string => {
    const address = MULTISIGS[eid]

    if (!address || address === 'TODO' || address === '0x0000000000000000000000000000000000000000') {
        throw new Error(
            `Multisig address not configured for endpoint ${eid}. Please update MULTISIGS in consts/wire.ts`
        )
    }

    return address
}

export const getSendLibrary = async (eid: EndpointId): Promise<string> => {
    const metadata = await fetchMetadata()
    const deployment = getEndpointIdDeployment(eid, metadata)

    if (!deployment) {
        throw new Error(`Can't find lz deployments for eid: "${eid}"`)
    }

    const { sendUln302 } = deployment

    if (!sendUln302) {
        throw new Error(`Can't find sendUln302 for eid: "${eid}"`)
    }

    if (!sendUln302.address) {
        throw new Error(`Can't find sendUln302 address for deployment with eid: "${eid}"`)
    }

    return sendUln302.address
}

export const getReceiveLibrary = async (eid: EndpointId): Promise<string> => {
    const metadata = await fetchMetadata()
    const deployment = getEndpointIdDeployment(eid, metadata)

    if (!deployment) {
        throw new Error(`Can't find lz deployments for eid: "${eid}"`)
    }

    const { receiveUln302 } = deployment

    if (!receiveUln302) {
        throw new Error(`Can't find receiveUln302 for eid: "${eid}"`)
    }

    if (!receiveUln302.address) {
        throw new Error(`Can't find receiveUln302 address for deployment with eid: "${eid}"`)
    }

    return receiveUln302.address
}

export const getExecutor = async (eid: EndpointId): Promise<string> => {
    const metadata = await fetchMetadata()
    const deployment = getEndpointIdDeployment(eid, metadata)

    if (!deployment) {
        throw new Error(`Can't find lz deployments for eid: "${eid}"`)
    }

    const { executor } = deployment

    if (!executor) {
        throw new Error(`Can't find executor for eid: "${eid}"`)
    }

    if (isSolanaDeployment(deployment)) {
        if (!executor.pda) {
            throw new Error(`Can't find executor PDA for Solana deployment`)
        }
        return executor.pda
    }

    if (!executor.address) {
        throw new Error(`Can't find executor address for deployment with eid: "${eid}"`)
    }

    return executor.address
}
