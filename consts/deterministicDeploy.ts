import { ethers } from 'ethers'

export const deterministicDeployment = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('frnt.deployment'))
