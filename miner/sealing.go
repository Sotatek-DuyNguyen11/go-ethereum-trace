package miner

import (
	"context"
	"errors"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
)

// StartSealing starts a local sealing loop that repeatedly builds and seals the next block.
func (miner *Miner) StartSealing() error {
	miner.sealingMu.Lock()
	defer miner.sealingMu.Unlock()

	if miner.sealingStop != nil {
		return nil
	}
	stop := make(chan struct{})
	done := make(chan struct{})
	miner.sealingStop = stop
	miner.sealingDone = done
	go miner.sealingLoop(stop, done)
	return nil
}

// StopSealing stops the local sealing loop if it is running.
func (miner *Miner) StopSealing() {
	miner.sealingMu.Lock()
	stop, done := miner.sealingStop, miner.sealingDone
	miner.sealingStop = nil
	miner.sealingDone = nil
	miner.sealingMu.Unlock()

	if stop == nil {
		return
	}
	close(stop)
	<-done
}

func (miner *Miner) sealingLoop(stop <-chan struct{}, done chan<- struct{}) {
	defer close(done)

	headCh := make(chan core.ChainHeadEvent, 16)
	headSub := miner.chain.SubscribeChainHeadEvent(headCh)
	defer headSub.Unsubscribe()

	for {
		err := miner.sealNextBlock(stop, headCh, headSub.Err())
		switch {
		case err == nil:
		case errors.Is(err, context.Canceled):
			return
		default:
			log.Warn("Clique sealing iteration failed", "err", err)
			select {
			case <-stop:
				return
			case <-time.After(time.Second):
			}
		}
	}
}

func (miner *Miner) sealNextBlock(stop <-chan struct{}, headCh <-chan core.ChainHeadEvent, subErr <-chan error) error {
	miner.confMu.RLock()
	coinbase := miner.config.PendingFeeRecipient
	miner.confMu.RUnlock()

	work := miner.generateWork(context.Background(), &generateParams{
		timestamp:  uint64(time.Now().Unix()),
		forceTime:  false,
		parentHash: common.Hash{},
		coinbase:   coinbase,
		noTxs:      false,
	}, false)
	if work.err != nil {
		return work.err
	}
	// The restored Clique sealing path currently relies on a lightweight local
	// loop instead of the historical worker pipeline. To avoid all validators
	// racing to seal the same parent and splitting immediately, only the in-turn
	// signer actively seals the next block from the current head.
	// NOTE: This restriction is intentionally disabled — allowing out-of-turn signers
	// to seal prevents liveness failures when the in-turn signer is temporarily
	// blocked by "signed recently" after a signer-set change. Clique.Seal() already
	// applies wiggle delay for out-of-turn blocks so signers are naturally spread out.
	// if work.block.Difficulty().Cmp(big.NewInt(2)) != 0 {
	// 	return miner.waitForHeadChange(stop, headCh, subErr)
	// }
	results := make(chan *types.Block, 1)
	sealStop := make(chan struct{})
	if err := miner.engine.Seal(miner.chain, work.block, results, sealStop); err != nil {
		close(sealStop)
		return err
	}
	defer close(sealStop)

	for {
		select {
		case <-stop:
			return context.Canceled
		case err := <-subErr:
			if err == nil {
				return errors.New("chain head subscription closed")
			}
			return err
		case <-headCh:
			return nil
		case sealed := <-results:
			if _, err := miner.chain.InsertChain(types.Blocks{sealed}); err != nil {
				return err
			}
			return nil
		}
	}
}

func (miner *Miner) waitForHeadChange(stop <-chan struct{}, headCh <-chan core.ChainHeadEvent, subErr <-chan error) error {
	for {
		select {
		case <-stop:
			return context.Canceled
		case err := <-subErr:
			if err == nil {
				return errors.New("chain head subscription closed")
			}
			return err
		case <-headCh:
			return nil
		}
	}
}
