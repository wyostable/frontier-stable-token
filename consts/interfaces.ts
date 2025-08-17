interface IMetadataDvns {
    [address: string]: {
        version: number
        canonicalName: string
        id: string
        deprecated?: boolean
        lzReadCompatible?: boolean
    }
}
export interface IMetadata {
    [key: string]: {
        deployments?: {
            eid: string
            chainKey: string
            sendUln302?: { address: string }
            receiveUln302?: { address: string }
            executor?: { address: string; pda?: string }
        }[]
        dvns?: IMetadataDvns
    }
}
