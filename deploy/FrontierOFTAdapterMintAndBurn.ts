import { type DeployFunction } from 'hardhat-deploy/types'

import { EndpointId, endpointIdToNetwork } from '@layerzerolabs/lz-definitions'
import { getDeploymentAddressAndAbi } from '@layerzerolabs/lz-evm-sdk-v2'

import { FRNT_TOKEN_ADDRESS } from '../consts/deploy'
import { deterministicDeployment } from '../consts/deterministicDeploy'

const contractName = 'FRNTAdapter'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts } = hre

    const { deploy } = hre.deployments
    const { deployer } = await getNamedAccounts()

    console.log(`deploying ${contractName} on network: ${hre.network.name} with ${deployer}`)

    const eid = hre.network.config.eid as EndpointId
    const lzNetworkName = endpointIdToNetwork(eid)
    const { address: endpointAddress } = getDeploymentAddressAndAbi(lzNetworkName, 'EndpointV2')
    const tokenAddress = FRNT_TOKEN_ADDRESS[eid]

    await deploy(contractName, {
        from: deployer,
        args: [tokenAddress, endpointAddress],
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: true,
        deterministicDeployment,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            owner: deployer,
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [deployer],
                },
            },
        },
        contract: 'FrontierOFTAdapterMintAndBurn',
    })
}

deploy.tags = [contractName]

export default deploy
