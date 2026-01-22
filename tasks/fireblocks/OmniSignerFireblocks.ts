import 'dotenv/config'

import { Fireblocks, TransactionOperation, TransactionRequest, TransferPeerPathType } from '@fireblocks/ts-sdk'
import { Connection, PublicKey, TransactionMessage, VersionedTransaction } from '@solana/web3.js'

import { OmniSigner, OmniTransactionReceipt, OmniTransactionResponse } from '@layerzerolabs/devtools'
import { deserializeTransactionMessage } from '@layerzerolabs/devtools-solana'
import { createLogger } from '@layerzerolabs/io-devtools'
import { EndpointId } from '@layerzerolabs/lz-definitions'

function encodeTransactionForFireblocks(tx: VersionedTransaction): string {
    return Buffer.from(tx.serialize()).toString('base64')
}

// Fireblocks signer implementation that submits transactions to Fireblocks instead of signing locally
export class OmniSignerFireblocks implements OmniSigner<OmniTransactionResponse<OmniTransactionReceipt>> {
    constructor(
        public eid: EndpointId,
        private connection: Connection,
        private fireblocks: Fireblocks,
        private vaultAccountId: string,
        private payer: PublicKey,
        private assetId = 'SOL_TEST'
    ) {}

    getPoint() {
        return { eid: this.eid, address: this.payer.toBase58() }
    }

    async sign(transaction: unknown): Promise<string> {
        const logger = createLogger('info')

        try {
            let versionedTransaction: VersionedTransaction | undefined = undefined

            if (
                typeof transaction === 'object' &&
                transaction &&
                'data' in transaction &&
                typeof transaction.data === 'string'
            ) {
                logger.info('Fireblocks: Handling LayerZero transaction with hex data')

                const hexData = transaction.data
                logger.info(`Fireblocks: Received hex data length: ${hexData.length} chars`)

                try {
                    logger.info('Fireblocks: Using LayerZero deserializeTransactionMessage')
                    const solanaTransaction = deserializeTransactionMessage(hexData)
                    logger.info('Fireblocks: Successfully deserialized LayerZero transaction')

                    // Update the transaction with fresh blockhash and set proper fee payer
                    const { blockhash } = await this.connection.getLatestBlockhash()
                    solanaTransaction.recentBlockhash = blockhash
                    solanaTransaction.feePayer = this.payer

                    // Convert to VersionedTransaction for Fireblocks
                    const message = new TransactionMessage({
                        payerKey: this.payer,
                        recentBlockhash: blockhash,
                        instructions: solanaTransaction.instructions,
                    })

                    versionedTransaction = new VersionedTransaction(message.compileToV0Message([]))
                    logger.info('Fireblocks: Successfully converted to VersionedTransaction for submission')
                } catch (error) {
                    logger.error(`Failed to deserialize LayerZero transaction: ${error}`)
                }
            } else {
                logger.error(`Unsupported transaction format: ${typeof transaction}`)
                logger.error(`Transaction: ${JSON.stringify(transaction, null, 2)}`)
                throw new Error(
                    `Unsupported transaction format: ${typeof transaction}. Expected VersionedTransaction, Transaction, instructions array, or serialized data`
                )
            }

            // Encode for Fireblocks
            if (versionedTransaction === undefined) {
                throw new Error('Failed to create VersionedTransaction for Fireblocks submission')
            }

            const serializedTransaction = encodeTransactionForFireblocks(versionedTransaction)
            logger.info(`Fireblocks: Encoded transaction length: ${serializedTransaction.length} chars`)
            logger.info(`Fireblocks: Transaction encoded successfully for submission`)

            const payload: TransactionRequest = {
                operation: TransactionOperation.ProgramCall,
                source: { type: TransferPeerPathType.VaultAccount, id: this.vaultAccountId },
                assetId: this.assetId,
                note: `LayerZero Wire Transaction - ${new Date().toISOString()}`,
                feeLevel: 'MEDIUM',
                extraParameters: {
                    programCallData: serializedTransaction,
                },
            }

            logger.info(`Submitting to Fireblocks: Vault=${this.vaultAccountId}, Asset=${this.assetId}`)

            const result = await this.fireblocks.transactions.createTransaction({
                transactionRequest: payload,
            })

            const transactionId = result.data?.id || 'fireblocks-pending'
            logger.info(`Transaction submitted successfully: ID=${transactionId}`)
            return transactionId
        } catch (error) {
            throw new Error(`Fireblocks transaction failed: ${error}`)
        }
    }

    async signAndSend(transaction: unknown): Promise<OmniTransactionResponse<OmniTransactionReceipt>> {
        const transactionHash = await this.sign(transaction)

        return {
            transactionHash,
            wait: async () => ({
                transactionHash,
                blockNumber: 0,
                blockHash: '',
                status: 1,
                confirmations: 0,
                logs: [],
                gasUsed: 0n,
                effectiveGasPrice: 0n,
                from: this.payer.toBase58(),
                to: '',
            }),
        } as OmniTransactionResponse<OmniTransactionReceipt>
    }
}
