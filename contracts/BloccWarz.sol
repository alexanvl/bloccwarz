pragma solidity 0.5.8;

import { MintAndBurnToken } from "./MintAndBurnToken.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract BloccWarz is Ownable {
  using SafeMath for uint256;

  // VARIABLES
  // Owner
  address payable public ownerAddr = ownerAddr;
  // Financial
  MintAndBurnToken public bwToken;
  uint256 public poolBalance = 0;
  uint256 public minTokenTransactionWei = 400; // enforce a minimum purchase/sale amount
  uint256 public transactionFeeAs1PctDenom = 4; // used to keep fee calculations as integers
  uint256 public tokenBWCWeiLockup = 1e21; // 1000 tokens will stay locked in the contract

  constructor ( ) public {
    bwToken = new MintAndBurnToken('BloccWarzCash', 18, 'BLCCWZC');
  }

  function buyTokens() public payable {
    // Purchase must be enough wei for contract to collect fee
    require(msg.value >= minTokenTransactionWei, "Must send minimum transaction amount to buy tokens");
    // Calculate fee as a fraction of 1%
    uint256 feeWei = SafeMath.div(SafeMath.div(msg.value, 100), transactionFeeAs1PctDenom);
    uint256 purchaseWei = SafeMath.sub(msg.value, feeWei);
    // Determine how many tokens to be minted
    // f(x) = 0.001x
    // F(x) = (x^2)/2000 + C
    // purchaseWei = ((bwToken.totalSupply() + tokensMinted)^2)/2000 - poolBalance
    // tokensMinted = sqrt(2000 * (purchaseWei + poolBalance)) - bwToken.totalSupply()
    uint256 tokensMinted = SafeMath.sub(
      sqrt(SafeMath.mul(2000, SafeMath.add(purchaseWei, poolBalance))),
      bwToken.totalSupply()
    );
    // mint tokens for sender
    bwToken.mint(msg.sender, tokensMinted);
    // incerement pool balance
    poolBalance = SafeMath.add(poolBalance, purchaseWei);
  }

  function sellTokens(uint256 _tokensBWCWei) public {
    require(_tokensBWCWei > 0, "Token amount for sale must be greater than 0");
    // Calculate wei value of tokens for sale
    // f(x) = 0.001x
    // F(x) = (x^2)/2000 + C
    // salePriceWei = poolBalance - ((bwToken.totalSupply() - _tokensBWCWei)^2)/2000
    uint256 targetTokenSupply = SafeMath.sub(bwToken.totalSupply(), _tokensBWCWei);
    uint256 salePriceWei = SafeMath.sub(
      poolBalance,
      SafeMath.div(
        SafeMath.mul(targetTokenSupply, targetTokenSupply),
        2000
      )
    );
    require(salePriceWei >= minTokenTransactionWei, "Token sale value must meet minimum transaction amount");
    // This should be impossible to trigger
    // require(poolBalance >= salePriceWei, "Contract balance insufficient for sale");
    // Calculate fee as a fraction of 1% of sale price
    uint256 feeWei = SafeMath.div(SafeMath.div(salePriceWei, 100), transactionFeeAs1PctDenom);
    uint256 sellerBalanceWei = SafeMath.sub(salePriceWei, feeWei);
    // transfer the tokens
    require(bwToken.transferFrom(msg.sender, address(this), _tokensBWCWei), "ERC-20 transferFrom failed");
    // Burn tokens
    bwToken.burn(_tokensBWCWei);
    // Pay seller
    msg.sender.transfer(sellerBalanceWei);
    // update pool balance
    poolBalance = SafeMath.sub(poolBalance, sellerBalanceWei);
  }

  function withdrawWei(uint256 _amountWei) public onlyOwner {
    // Owner can never take from the pool, only contract profits
    require(_amountWei <= SafeMath.sub(address(this).balance, poolBalance), "Withdraw exceeds limit");
    ownerAddr.transfer(_amountWei);
  }

  function withdrawTokens(uint256 _tokensBWCWei) public onlyOwner {
    // Owner can withdraw tokens collected by the contract above the lockup amount
    require(bwToken.balanceOf(address(this)) > tokenBWCWeiLockup, "Not enough tokens locked up");
    require(bwToken.transfer(ownerAddr, _tokensBWCWei), "Contract has not enough tokens for withdraw");
  }

  // UTIL

  function sqrt(uint x) internal pure returns (uint y) {
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
  }

  // FALLBACK

  function() external payable {}
}
