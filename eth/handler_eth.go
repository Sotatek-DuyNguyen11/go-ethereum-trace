// Copyright 2020 The go-ethereum Authors
// This file is part of the go-ethereum library.
//
// The go-ethereum library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-ethereum library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.

package eth

import (
	"errors"
	"fmt"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/eth/protocols/eth"
	"github.com/ethereum/go-ethereum/p2p/enode"
)

// ethHandler implements the eth.Backend interface to handle the various network
// packets that are sent as replies or broadcasts.
type ethHandler handler

func (h *ethHandler) Chain() *core.BlockChain { return h.chain }
func (h *ethHandler) TxPool() eth.TxPool      { return h.txpool }

// RunPeer is invoked when a peer joins on the `eth` protocol.
func (h *ethHandler) RunPeer(peer *eth.Peer, hand eth.Handler) error {
	return (*handler)(h).runEthPeer(peer, hand)
}

// PeerInfo retrieves all known `eth` information about a peer.
func (h *ethHandler) PeerInfo(id enode.ID) interface{} {
	if p := h.peers.peer(id.String()); p != nil {
		return p.info()
	}
	return nil
}

// AcceptTxs retrieves whether transaction processing is enabled on the node
// or if inbound transactions should simply be dropped.
func (h *ethHandler) AcceptTxs() bool {
	return h.synced.Load()
}

// Handle is invoked from a peer's message handler when it receives a new remote
// message that the handler couldn't consume and serve itself.
func (h *ethHandler) Handle(peer *eth.Peer, packet eth.Packet) error {
	// Consume any broadcasts and announces, forwarding the rest to the downloader
	switch packet := packet.(type) {
	case *eth.NewPooledTransactionHashesPacket:
		return h.txFetcher.Notify(peer.ID(), packet.Types, packet.Sizes, packet.Hashes)

	case *eth.TransactionsPacket:
		txs, err := packet.Items()
		if err != nil {
			return fmt.Errorf("Transactions: %v", err)
		}
		if err := handleTransactions(peer, txs, true); err != nil {
			return fmt.Errorf("Transactions: %v", err)
		}
		return h.txFetcher.Enqueue(peer.ID(), txs, false)

	case *eth.PooledTransactionsPacket:
		txs, err := packet.List.Items()
		if err != nil {
			return fmt.Errorf("PooledTransactions: %v", err)
		}
		if err := handleTransactions(peer, txs, false); err != nil {
			return fmt.Errorf("PooledTransactions: %v", err)
		}
		return h.txFetcher.Enqueue(peer.ID(), txs, true)

	default:
		return fmt.Errorf("unexpected eth packet type: %T", packet)
	}
}

// HandleBlockRangeUpdate reacts to remote head announcements by fetching the
// announced header and feeding it into the beacon-style sync path.
func (h *ethHandler) HandleBlockRangeUpdate(peer *eth.Peer, update *eth.BlockRangeUpdatePacket) error {
	peer.SetBlockRange(update)

	current := h.chain.CurrentBlock()
	if update.LatestBlock < current.Number.Uint64() {
		return nil
	}
	if update.LatestBlock == current.Number.Uint64() && update.LatestBlockHash == current.Hash() {
		return nil
	}
	go h.syncPeerHead(peer, *update)
	return nil
}

func (h *ethHandler) syncPeerHead(peer *eth.Peer, update eth.BlockRangeUpdatePacket) {
	sink := make(chan *eth.Response, 1)
	req, err := peer.RequestOneHeader(update.LatestBlockHash, sink)
	if err != nil {
		peer.Log().Debug("Failed to request announced head", "hash", update.LatestBlockHash, "err", err)
		return
	}
	defer req.Close()

	select {
	case res := <-sink:
		headers, ok := res.Res.(*eth.BlockHeadersRequest)
		if !ok {
			res.Done <- fmt.Errorf("unexpected response type %T", res.Res)
			return
		}
		if len(*headers) != 1 {
			res.Done <- fmt.Errorf("unexpected header count %d", len(*headers))
			return
		}
		header := (*headers)[0]
		if header.Hash() != update.LatestBlockHash || header.Number.Uint64() != update.LatestBlock {
			res.Done <- fmt.Errorf("announced head mismatch")
			return
		}
		err := h.downloader.BeaconDevSync(header)
		res.Done <- nil
		if err != nil {
			peer.Log().Debug("Failed to sync chain to announced head", "number", header.Number.Uint64(), "hash", header.Hash(), "err", err)
		}

	case <-peer.Term():
		return
	case <-time.After(syncChallengeTimeout):
		peer.Log().Debug("Timed out fetching announced head", "hash", update.LatestBlockHash, "number", update.LatestBlock)
	}
}

// handleTransactions marks all given transactions as known to the peer
// and performs basic validations.
func handleTransactions(peer *eth.Peer, list []*types.Transaction, directBroadcast bool) error {
	seen := make(map[common.Hash]struct{})
	for _, tx := range list {
		if tx.Type() == types.BlobTxType {
			if directBroadcast {
				return errors.New("disallowed broadcast blob transaction")
			} else {
				// If we receive any blob transactions missing sidecars, or with
				// sidecars that don't correspond to the versioned hashes reported
				// in the header, disconnect from the sending peer.
				if tx.BlobTxSidecar() == nil {
					return errors.New("received sidecar-less blob transaction")
				}
				if err := tx.BlobTxSidecar().ValidateBlobCommitmentHashes(tx.BlobHashes()); err != nil {
					return err
				}
			}
		}

		// Check for duplicates.
		hash := tx.Hash()
		if _, exists := seen[hash]; exists {
			return fmt.Errorf("multiple copies of the same hash %v", hash)
		}
		seen[hash] = struct{}{}

		// Mark as known.
		peer.MarkTransaction(hash)
	}
	return nil
}
