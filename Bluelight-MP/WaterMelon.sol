//SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "./Ownable.sol";
import "./CLG.sol";
import "./IWaterMelon.sol";
import "./Address.sol";
import "./Helper.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./IUserDashboard.sol";
import "./ReentrancyGuard.sol";

    /// we can bid only through tokens, can't do with currency***********************************
    /// balance mapping name correct.
        
contract WaterMelon is IWaterMelon, Helper, Ownable, ReentrancyGuard{
    using SafeMath for uint;
    using Address for address;

    enum OrderType{
        None, 
        Fixed,
        Auction
    }
    enum OrderStatus{
        None,
        MarketOpen,
        MarketCancelled,
        MarketClosed
    }
    struct Market{
        address contractAddress;
        uint256 tokenId;
        string ipfs;
        OrderType orderType;
        OrderStatus orderStatus;
        uint256 askAmount;
        uint256 maxAskAmount;
        address payable currentOwner;
        address newOwner;
        uint marketCreationTime;
        uint currentHighestBid;
        address currentHighestBidder;
        uint auctionEndTime;
    } 
    
    IERC20 private _erc20Token;
    IUserDashboard private _userDashboard;
    uint256 private _feePercent;
    address  payable private _platformFeeAddr;
    mapping (bytes32 => Market) private markets;
    
    constructor(address erc20Token,  address payable platformFeeAddr, uint256 feePercent) {
        _feePercent = feePercent;    
        _platformFeeAddr = platformFeeAddr;
        _erc20Token = IERC20(erc20Token);
    }
    function setUserDashboard (address userDashboard) external virtual override onlyOwner{
        _userDashboard = IUserDashboard(userDashboard);
    }
    function setERC20Token (address erc20Token) external virtual override onlyOwner{
        _erc20Token = IERC20(erc20Token); 
    }
    function setFeePercent (uint256 value) external virtual override onlyOwner{
        _feePercent = value; 
    }
    function setPlatformAddr (address payable _addr) external virtual override onlyOwner{
        _platformFeeAddr = _addr; 
    }
    function getMarketObj(address nftContractAddress, uint256 tokenId) public view 
            returns (OrderStatus  orderStatus,OrderType  orderType,uint price, uint maxPrice,
                    address nftAddress, uint tokenID, address currentOwner, address newOwner, uint marketCreationTime,
                    uint currentHighestBid, address currentHighestBidder, uint auctionEndTime){
        
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        require (markets[uniqueKey].orderStatus != OrderStatus.None, "Market object not created.");
        
        if (markets[uniqueKey].orderType == OrderType.Auction){
        return (markets[uniqueKey].orderStatus, markets[uniqueKey].orderType, markets[uniqueKey].askAmount,
                markets[uniqueKey].maxAskAmount, markets[uniqueKey].contractAddress, markets[uniqueKey].tokenId,
                markets[uniqueKey].currentOwner,markets[uniqueKey].newOwner, markets[uniqueKey].marketCreationTime,
                markets[uniqueKey].currentHighestBid,markets[uniqueKey].currentHighestBidder, markets[uniqueKey].auctionEndTime);
        }
        else{
        return (markets[uniqueKey].orderStatus, markets[uniqueKey].orderType, markets[uniqueKey].askAmount, 0,
        markets[uniqueKey].contractAddress, markets[uniqueKey].tokenId, markets[uniqueKey].currentOwner,markets[uniqueKey].newOwner, 
        markets[uniqueKey].marketCreationTime,0,address(0),0);
        }
    }   
    /*Need to list currency and tokens with different amount as per thier price difference ...method needed...*/
    /////////////////// Listing NFT /////////////////////////////
    function listNFT(address nftContractAddress, uint256 tokenId, string memory iPFS, uint256 price, 
                    OrderType orderType, uint256 maxPrice, uint256 auctionEndTime) private{
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        IERC721 nftContract = IERC721(nftContractAddress);
        // adding these 2 checks here because in last code anyone can list nft other than owner and not check approval of Marketplace.
        require (nftContract.getApproved(tokenId) == address(this), "MP is not approved.");
        require (nftContract.ownerOf(tokenId) == msg.sender, "caller is not token owner.");
        require (markets[uniqueKey].orderStatus != OrderStatus.MarketOpen, "Market order is already opened");
        require (price > 0,"Price Should be greater then 0");
        require (_userDashboard.checkLogIn(msg.sender), "for listing this nft, create account first or login to your account.");
        
        uint endTime = block.timestamp + auctionEndTime;

        markets[uniqueKey].orderStatus = OrderStatus.MarketOpen; 
        markets[uniqueKey].orderType = orderType;
        markets[uniqueKey].askAmount = price;
        markets[uniqueKey].maxAskAmount = maxPrice;
        markets[uniqueKey].contractAddress = nftContractAddress;
        markets[uniqueKey].tokenId = tokenId;
        markets[uniqueKey].ipfs = iPFS;
        markets[uniqueKey].currentOwner = payable(msg.sender);
        markets[uniqueKey].marketCreationTime = block.timestamp;
        markets[uniqueKey].auctionEndTime = endTime;
        markets[uniqueKey].currentHighestBid = 0; ///after buying any nft, If new owner wanted to list nft of same 
        // tokenId, then currentHighestBid and newOwner values remain same as per last market.(this was error here but now resolved) 
        markets[uniqueKey].newOwner = address(0); 
        markets[uniqueKey].currentHighestBidder = address(0);

        _userDashboard.setNftData(msg.sender, nftContractAddress, tokenId, iPFS);
    }
    function listNFTForFixedType(address nftContractAddress, uint256 tokenId, string memory iPFS, uint256 price) external virtual override{
        listNFT(nftContractAddress,tokenId, iPFS, price,OrderType.Fixed, 0,0);
    } 
    function listNFTForAuctionType(address nftContractAddress, uint256 tokenId,string memory iPFS, uint256 price, uint256 maxPrice, uint256 auctionEndTime) external virtual override{
        require (price < maxPrice, "end Price Should be greater than price"); 
        require (auctionEndTime > 0, "time must be real."); 
        // uint day = auctionEndTime * 1 days; for days uncomment this and pass day below.
        uint timeMinute = auctionEndTime * 1 minutes;
        listNFT(nftContractAddress, tokenId,iPFS, price, OrderType.Auction, maxPrice, timeMinute);
    }      
    /////////////////// Buying fix ///////////////////////////
    function buyCurFixNFT(address nftContractAddress, uint256 tokenId ) external virtual override nonReentrant payable{ 
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        uint _amountValue = msg.value;
                
        (uint fee, uint royalityFee, uint ownerShare, address creator, IERC721 nftContract) =  
        fixedBuyingMethod(nftContractAddress, tokenId, msg.sender, _amountValue);
            
        // transfer nft to new user 
        nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, msg.sender, tokenId);
        
        _platformFeeAddr.transfer(fee);
        payable(creator).transfer(royalityFee); 
        markets[uniqueKey].currentOwner.transfer(ownerShare);

        _userDashboard.setAmountRecord(creator,0,0,royalityFee,0); 
        _userDashboard.setAmountRecord(markets[uniqueKey].currentOwner,0,0,ownerShare,0); 
        _userDashboard.setAmountRecord(msg.sender,_amountValue,0,0,0); 
        
        _userDashboard.setNftData(msg.sender, nftContractAddress, tokenId, iPFS);

        // _userDashboard.setNftData(msg.sender, nftContractAddress, tokenId, price, maxPrice, 0,address(0), block.timestamp, endTime);

    }
    function buyTokenFixNFT(address nftContractAddress, uint256 tokenId, uint price) external virtual override nonReentrant {  
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        
        require(_erc20Token.allowance(msg.sender, address(this)) >= price, "You need to approve amount to MP.");

        (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract) 
        = fixedBuyingMethod(nftContractAddress, tokenId, msg.sender, price);
        // transfer nft to new user 
        
        nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, msg.sender, tokenId);
        
        _erc20Token.transferFrom(msg.sender, address(this),price);
        _erc20Token.transfer(_platformFeeAddr, fee);
        _erc20Token.transfer(creator, royalityFee);
        _erc20Token.transfer(markets[uniqueKey].currentOwner, ownerShare);    

        _userDashboard.setAmountRecord(creator,0,0,0,royalityFee); 
        _userDashboard.setAmountRecord(markets[uniqueKey].currentOwner,0,0,0,ownerShare); 
        _userDashboard.setAmountRecord(msg.sender,0,price,0,0); 
    } 
    function fixedBuyingMethod(address nftContractAddress, uint256 tokenID, address newOwner, uint _amountValue) private returns (uint, uint,uint,address, IERC721 )  {
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenID);
        require (_userDashboard.checkLogIn(newOwner), "for fixed buying, create account first or login to your account."); 
        require(markets[uniqueKey].orderStatus == OrderStatus.MarketOpen, "Market order is not opened or not existed" ); 
        require(markets[uniqueKey].orderType != OrderType.Auction, "To buy nft auction type buy with bidTokenNFT." ); 
        //Buying got done only with equal amount not less or higher amount will be accepted.
        require(markets[uniqueKey].askAmount == _amountValue, "Value not matched");

        IERC721 nftContract = IERC721(markets[uniqueKey].contractAddress);
        (uint256 royality, address creator) = nftContract.getRoyalityDetails(tokenID);

        //platform fee
        uint256 fee = getFeePercentage(_amountValue, _feePercent);

        // Royality 
        uint256 royalityFee = getFeePercentage(_amountValue, royality);
        
        uint256 ownerShare = _amountValue.sub(fee.add(royalityFee));
        
        // nft market close
        markets[uniqueKey].orderStatus = OrderStatus.MarketClosed;
        markets[uniqueKey].newOwner = newOwner;

        return (fee, royalityFee, ownerShare, creator, nftContract);
    }
    //////////////////// Cancel Market////////////////////////
    function cancel(address nftContractAddress,  uint256 tokenId) external virtual override{
     
        bytes32 uniqueKey = getPrivateUniqueKey (nftContractAddress, tokenId);
     
        require (markets[uniqueKey].currentOwner == msg.sender, "only for market operator");
        require (_userDashboard.checkLogIn(msg.sender), "for cancel this listing, create account first or login to your account.");
        require (markets[uniqueKey].orderStatus == OrderStatus.MarketOpen, "Market order is not opened");
        
        markets[uniqueKey].orderStatus =  OrderStatus.MarketCancelled; 
    }
    /////////////////// Bid Section /////////////////////////
    function bidTokenNFT(address nftContractAddress, uint tokenId, uint amount) external virtual override{  
        //bidder need to approve MP for bid amount then at calling bidToken method MP will transfer tokens to MP.
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        uint maxTime = markets[uniqueKey].auctionEndTime;
        uint currentTime = block.timestamp;

        // In bid method MP will consider Time and highest bid. in time, if some one bid equal and greater than to max ask amount, he'll qualify the bid otherwise bid remain till 
        // end time. Mp don't need to add check for allowance of tokens from bidder side. 
        require(markets[uniqueKey].orderType != OrderType.Fixed, "To buy nft fixed type buy with buyCurFixNFT/buyTokenFixNFT." ); 
        require (maxTime > currentTime, "Bid time is over.");
        require (markets[uniqueKey].currentHighestBid < amount, "your bid not higher than highest bid.");
        require (_userDashboard.checkLogIn(msg.sender), "for bidding, create account first or login to your account.");

        
            if( markets[uniqueKey].maxAskAmount <= amount ) {
            markets[uniqueKey].currentHighestBid = amount;
            markets[uniqueKey].currentHighestBidder = msg.sender;

            (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract)= 
            auctionBuyingMethod(nftContractAddress, tokenId, amount, msg.sender);
                

            nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, msg.sender, tokenId);
        
            _erc20Token.transferFrom(msg.sender, address(this),amount);
            _erc20Token.transfer(_platformFeeAddr, fee);
            _erc20Token.transfer(creator, royalityFee);
            _erc20Token.transfer(markets[uniqueKey].currentOwner, ownerShare); 

            console.log("You won the bid. your bid is > or = maxAskAmount.");
            }
            else{
            markets[uniqueKey].currentHighestBid = amount;
            markets[uniqueKey].currentHighestBidder = msg.sender;
            
            console.log("your bid is current highest bid, but not eligible to buy.");
            }               
    }
    function auctionBuyingMethod(address nftContractAddress, uint256 tokenID, uint _amountValue, address _newOwner) private  returns (uint, uint,uint,address, IERC721 )  {
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenID);
       
        require(markets[uniqueKey].orderStatus == OrderStatus.MarketOpen, "Market order is not opened or not existed" ); 

        IERC721 nftContract = IERC721(markets[uniqueKey].contractAddress);
        (uint256 royality, address creator) = nftContract.getRoyalityDetails(tokenID);

        //platform fee
        uint256 fee = getFeePercentage(_amountValue, _feePercent);

        // Royality 
        uint256 royalityFee = getFeePercentage(_amountValue, royality);

        uint256 ownerShare = _amountValue.sub(fee.add(royalityFee));

        // nft market close
        markets[uniqueKey].orderStatus = OrderStatus.MarketClosed;
        markets[uniqueKey].newOwner = _newOwner;
        uint amount = _amountValue;

        _userDashboard.setAmountRecord(creator,0,0,0,royalityFee); 
        _userDashboard.setAmountRecord(markets[uniqueKey].currentOwner,0,0,0,ownerShare); 
        _userDashboard.setAmountRecord(msg.sender,0,amount,0,0); 

        return (fee, royalityFee, ownerShare, creator, nftContract);
    }
    function auctionTokenTimeOver(address nftContractAddress, uint256 tokenId) external virtual override onlyOwner{
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        uint maxTime = markets[uniqueKey].auctionEndTime;
        uint currentTime = block.timestamp; 
        uint amount = markets[uniqueKey].currentHighestBid ;
        address successfulBidder = markets[uniqueKey].currentHighestBidder ;
        
        require (maxTime <= currentTime, "Bid is runing.");
        (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract)= 
            auctionBuyingMethod(nftContractAddress, tokenId, amount, successfulBidder);
       
        nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, successfulBidder, tokenId);
    
        _erc20Token.transferFrom(successfulBidder, address(this), amount);
        _erc20Token.transfer(_platformFeeAddr, fee);
        _erc20Token.transfer(creator, royalityFee);
        _erc20Token.transfer(markets[uniqueKey].currentOwner, ownerShare); 
        console.log("You won the bid. you're the highest bidder.");
    }
}


    