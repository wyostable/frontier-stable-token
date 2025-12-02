import { EndpointId } from '@layerzerolabs/lz-definitions'
import { OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

import { getEnforcedOptions } from './consts/wire'
import { getOftStoreAddress } from './tasks/solana'

// Define all contracts
const CONTRACTS: OmniPointHardhat[] = [
    { eid: EndpointId.AMOY_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.AVALANCHE_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.SEPOLIA_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.ARBSEP_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.OPTSEP_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.BASESEP_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.HEDERA_V2_TESTNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.SOLANA_V2_TESTNET, address: getOftStoreAddress(EndpointId.SOLANA_V2_TESTNET) },
]

// Generate all possible connections
const generateConnections = () => {
    const connections = []

    // Generate all directional pairs first (including both directions)
    const pairs = []
    for (let i = 0; i < CONTRACTS.length; i++) {
        for (let j = 0; j < CONTRACTS.length; j++) {
            if (i !== j) {
                // Skip self-connections
                pairs.push([CONTRACTS[i], CONTRACTS[j]]) // from -> to
            }
        }
    }

    // Iterate through all directional pairs
    for (const [from, to] of pairs) {
        connections.push({
            from,
            to,
            config: {
                enforcedOptions: getEnforcedOptions(to.eid),
            },
        })
    }

    return connections
}

export default async function () {
    const connections = generateConnections()

    return {
        contracts: CONTRACTS.map((contract) => ({
            contract,
        })),
        connections,
    }
}
