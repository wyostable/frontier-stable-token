import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { OAppEnforcedOption } from '@layerzerolabs/toolbox-hardhat'

export const DVNS = {
    CANARY: {
        [EndpointId.ARBITRUM_V2_MAINNET]: '0xf2e380c90e6c09721297526dbc74f870e114dfcb',
        [EndpointId.AVALANCHE_V2_MAINNET]: '0xcc49e6fca014c77e1eb604351cc1e08c84511760',
        [EndpointId.BASE_V2_MAINNET]: '0x554833698ae0fb22ecc90b01222903fd62ca4b47',
        [EndpointId.ETHEREUM_V2_MAINNET]: '0xa4fe5a5b9a846458a70cd0748228aed3bf65c2cd',
        [EndpointId.OPTIMISM_V2_MAINNET]: '0x5b6735c66d97479ccd18294fc96b3084ecb2fa3f',
        [EndpointId.POLYGON_V2_MAINNET]: '0x13feb7234ff60a97af04477d6421415766753ba3',
        [EndpointId.SOLANA_V2_MAINNET]: '7jMeX5mzXnSSKYd8DxBDP4xMnkNFZZZm5W28FWUTbwU3',
        [EndpointId.HEDERA_V2_MAINNET]: '0x4b92bc2a7d681bf5230472c80d92acfe9a6b9435',
    } as Partial<Record<EndpointId, string>>,
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
        [EndpointId.HEDERA_V2_MAINNET]: '0xce8358bc28dd8296ce8caf1cd2b44787abd65887',
    } as Partial<Record<EndpointId, string>>,
    WYOMING: {
        [EndpointId.ARBITRUM_V2_MAINNET]: '0xcb1b1d524d013a32e976a5963bd541c388ec0517',
        [EndpointId.AVALANCHE_V2_MAINNET]: '0xda4428ff0f15b9d92c39ae08c4fc2f1216662c2f',
        [EndpointId.BASE_V2_MAINNET]: '0xf80285efb7518d5c79f4e98e3baa59da5ee79621',
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x6c70db9ce65fa37499c1f1a150a6440fc9c7273a',
        [EndpointId.OPTIMISM_V2_MAINNET]: '0x94ec5934daa761d7597b76fd0fecf8385de143be',
        [EndpointId.POLYGON_V2_MAINNET]: '0xf6cb110b0334825797b9b733060229c68e5d8bef',
        [EndpointId.SOLANA_V2_MAINNET]: '6bdMfqghzhFpMsbrfy6qiyXnGkYGcamn3WYxeKx8Muik',
        [EndpointId.HEDERA_V2_MAINNET]: '0x5c58c83736ebba703afe5784efd95f02ca30d3d3',
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
    [EndpointId.HEDERA_V2_TESTNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 120000, value: 0 }],
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
    [EndpointId.HEDERA_V2_MAINNET]: [{ msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100000, value: 0 }],
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
    [EndpointId.HEDERA_V2_MAINNET]: '0xdA769654D7c66375420ed67135A711521C3bB296',
    [EndpointId.SOLANA_V2_MAINNET]: '3FL7iZaerXVygpPAFtXyxoCGdoUt11eiSBYkko6mMD8x',
    // Testnet addresses
    [EndpointId.AMOY_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.ARBSEP_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.AVALANCHE_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.BASESEP_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.OPTSEP_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.SEPOLIA_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.HEDERA_V2_TESTNET]: '0x8cE5b7298707F672ae8C1e8eba69Fe4f840Ee0eC',
    [EndpointId.SOLANA_V2_TESTNET]: '4gN2LgUyrxqjChDP3mDFbKNyDrZsPYS81NHQ4yhd9MHe',
} as const

// Helper functions
export const getRequiredDVNs = (eid: EndpointId): string[] => {
    return [DVNS.WYOMING[eid]].filter(Boolean) as string[]
}

export const getOptionalDVNs = (fromEid: EndpointId, toEid: EndpointId): string[] => {
    const isHederaPath = fromEid === EndpointId.HEDERA_V2_MAINNET || toEid === EndpointId.HEDERA_V2_MAINNET
    if (isHederaPath) {
        return [DVNS.CANARY[fromEid], DVNS.LZ_LABS[fromEid]].filter(Boolean) as string[]
    }
    return [DVNS.GOOGLE_CLOUD[fromEid], DVNS.LZ_LABS[fromEid]].filter(Boolean) as string[]
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
