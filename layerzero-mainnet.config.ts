import { EndpointId } from '@layerzerolabs/lz-definitions'
import { OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

import { getEnforcedOptions, getMultisigAddress, getOptionalDVNs, getRequiredDVNs } from './consts/wire'
import { getOftStoreAddress } from './tasks/solana'

// Define all contracts
const CONTRACTS: OmniPointHardhat[] = [
    { eid: EndpointId.ARBITRUM_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.AVALANCHE_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.BASE_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.ETHEREUM_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.OPTIMISM_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.POLYGON_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.HEDERA_V2_MAINNET, contractName: 'FRNTAdapter' },
    { eid: EndpointId.SOLANA_V2_MAINNET, address: getOftStoreAddress(EndpointId.SOLANA_V2_MAINNET) },
]

// Generate all possible connections
const generateConnections = async () => {
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
                sendConfig: {
                    ulnConfig: {
                        requiredDVNs: getRequiredDVNs(from.eid),
                        optionalDVNs: getOptionalDVNs(from.eid, to.eid),
                        optionalDVNThreshold: 1,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        requiredDVNs: getRequiredDVNs(from.eid),
                        optionalDVNs: getOptionalDVNs(from.eid, to.eid),
                        optionalDVNThreshold: 1,
                    },
                },
            },
        })
    }

    return connections
}

export default async function () {
    const connections = await generateConnections()

    return {
        contracts: CONTRACTS.map((contract) => ({
            contract,
            config: {
                owner: getMultisigAddress(contract.eid),
                delegate: getMultisigAddress(contract.eid),
            },
        })),
        connections,
    }
}
