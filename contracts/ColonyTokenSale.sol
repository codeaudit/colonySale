pragma solidity^0.4.11;

import "./Token.sol";
import "./dappsys/math.sol";


contract ColonyTokenSale is DSMath {
  // Block number in which the sale starts. Inclusive. Sale will be opened at start block.
  uint public startBlock;
  // Sale will continue for a maximum of 71153 blocks (~14 days). Initialised as the latest possible block number at which the sale ends.
  // Updated if softCap reached to the number of blocks it took to reach the soft cap and it is a min of 635 and max 5082.
  // Exclusive. Sale will be closed at end block.
  uint public endBlock;
  // Once softCap is reached, the remaining sale duration is set to the same amount of blocks it's taken the sale to reach the softCap
  // minumum and maximum are 635 and 5082 blocks corresponding to roughly 3 and 24 hours.
  uint public postSoftCapMinBlocks;
  uint public postSoftCapMaxBlocks;
  // CLNY token wei price, at the start of the sale
  uint constant public tokenPrice = 1 finney;
  // Minimum contribution amount
  uint constant public minimumContribution = 1 finney;
  // Total amount raised
  uint public totalRaised = 0 ether;
  // Sale soft cap
  uint public softCap;
  // The address to hold the funds donated
  address public colonyMultisig;
  // The address of the Colony Network Token
  Token public token;

  modifier saleOpen {
      assert(getBlockNumber() >= startBlock);
      assert(getBlockNumber() < endBlock);
      _;
  }

  modifier overMinContribution {
    assert(msg.value >= minimumContribution);
    _;
  }

  function ColonyTokenSale (
    uint _startBlock,
    uint _softCap,
    uint _postSoftCapMinBlocks,
    uint _postSoftCapMaxBlocks,
    uint _maxSaleDurationBlocks,
    address _token,
    address _colonyMultisig) {
    // Validate duration params that 0 < postSoftCapMinBlocks < postSoftCapMaxBlocks
    if (_postSoftCapMinBlocks == 0) { throw; }
    if (_postSoftCapMinBlocks >= _postSoftCapMaxBlocks) { throw; }

    // TODO validate startBLock > block.number;
    startBlock = _startBlock;
    endBlock = add(startBlock, _maxSaleDurationBlocks);
    softCap = _softCap;
    postSoftCapMinBlocks = _postSoftCapMinBlocks;
    postSoftCapMaxBlocks = _postSoftCapMaxBlocks;
    token = Token(_token);
    colonyMultisig = _colonyMultisig;
  }

  function getBlockNumber() constant returns (uint) {
    return block.number;
  }

  function buy(address _owner) internal
  overMinContribution
  saleOpen
  {
    // Send funds to multisig, throws on failure
    colonyMultisig.transfer(msg.value);

    // Calculate token amount purchased for given value and generate purchase
    uint amount = div(msg.value, tokenPrice); //TODO we use wei only, should we be working with token numbers?
    uint128 hamount = uint128(amount);
    token.mint(hamount);
    token.transfer(_owner, amount);
    
    // Up the total raised with given value
    totalRaised = add(msg.value, totalRaised);

    // When softCap is reached, calculate the remainder sale duration in blocks.
    if (totalRaised >= softCap) {
      uint updatedEndBlock;
      uint currentBlock = block.number;
      uint blocksInSale = sub(currentBlock, startBlock);
      if (blocksInSale < postSoftCapMinBlocks) {
        updatedEndBlock = add(currentBlock, postSoftCapMinBlocks);
      } else if (blocksInSale > postSoftCapMaxBlocks) {
        updatedEndBlock = add(currentBlock, postSoftCapMaxBlocks);
      } else {
        updatedEndBlock = add(currentBlock, blocksInSale);
      }

      // We cannot exceed the longest sale duration.
      if (updatedEndBlock < endBlock) {
        endBlock = updatedEndBlock;
      }
    }
  }

  function () public payable {
    return buy(msg.sender);
  }
}
