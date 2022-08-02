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

    //////////////////// Errors
    // string constant ZERO_ADDRESS = "WM-1";
    // string constant NOT_VALID_NFT = "WM-2";
    // string constant NOT_OWNER_OR_OPERATOR = "WM-3";
    string constant MP_NOT_APPROVED = "WM-4";
    string constant BID_RUNNING = "WM-5";
    string constant CREATE_ACC_OR_LOGIN = "WM-6";
    string constant PRICE_LESS_THAN_ZERO = "WM-7";
    string constant MARKET_ORDER_OPENED = "WM-8";
    string constant MARKET_ORDER_NOT_OPENED = "WM-9"; 
    string constant VALUE_NOT_MATCHED = "WM-10";  
    string constant NOT_REAL_TIME = "WM-11";  
    string constant NFT_NOT_LISTED = "WM-12";  

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
        require (markets[uniqueKey].orderStatus != OrderStatus.None, NFT_NOT_LISTED);
        
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
    function listNFT(address nftContractAddress, uint256 tokenId, uint256 price, 
                    OrderType orderType, uint256 maxPrice, uint256 auctionEndTime) private{
        (bytes32 uniqueKey,,,, address owner, string memory iPFS) =_userDashboard.getNft( nftContractAddress, tokenId);
        IERC721 nftContract = IERC721(nftContractAddress);
        // adding these 2 checks here because in last code anyone can list nft other than owner and not check approval of Marketplace.
        require (nftContract.getApproved(tokenId) == address(this), "MP is not approved.");
        require (nftContract.ownerOf(tokenId) == msg.sender, "caller is not token owner.");
        require (markets[uniqueKey].orderStatus != OrderStatus.MarketOpen, MARKET_ORDER_OPENED);
        require (price > 0, PRICE_LESS_THAN_ZERO);
        require (_userDashboard.checkLogIn(msg.sender), CREATE_ACC_OR_LOGIN);
        
        uint endTime = block.timestamp + auctionEndTime;

        markets[uniqueKey].orderStatus = OrderStatus.MarketOpen; 
        markets[uniqueKey].orderType = orderType;
        markets[uniqueKey].askAmount = price;
        markets[uniqueKey].maxAskAmount = maxPrice;
        markets[uniqueKey].contractAddress = nftContractAddress;
        markets[uniqueKey].tokenId = tokenId;
        markets[uniqueKey].ipfs = iPFS;
        markets[uniqueKey].currentOwner = payable(owner);
        markets[uniqueKey].marketCreationTime = block.timestamp;
        markets[uniqueKey].auctionEndTime = endTime;
        markets[uniqueKey].currentHighestBid = 0; ///after buying any nft, If new owner wanted to list nft of same 
        // tokenId, then currentHighestBid and newOwner values remain same as per last market.(this was error here but now resolved) 
        markets[uniqueKey].newOwner = address(0); 
        markets[uniqueKey].currentHighestBidder = address(0);

    }
    function listNFTForFixedType(address nftContractAddress, uint256 tokenId, uint256 price) external virtual override{
        listNFT(nftContractAddress,tokenId, price,OrderType.Fixed, 0,0);
    } 
    function listNFTForAuctionType(address nftContractAddress, uint256 tokenId, uint256 price, uint256 maxPrice, uint256 auctionEndTime) external virtual override{
        require (price < maxPrice, "end Price Should be greater than price"); 
        require (auctionEndTime > 0, NOT_REAL_TIME); 
        // uint day = auctionEndTime * 1 days; for days uncomment this and pass day below.
        uint timeMinute = auctionEndTime * 1 minutes;
        listNFT(nftContractAddress, tokenId, price, OrderType.Auction, maxPrice, timeMinute);
    }      
    /////////////////// Buying fix ///////////////////////////
    function buyCurFixNFT(address nftContractAddress, uint256 tokenId ) external virtual override nonReentrant payable{ 
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        uint _amountValue = msg.value;
                
        (uint fee, uint royalityFee, uint ownerShare, address creator, IERC721 nftContract) =  
        fixedBuyingMethod(uniqueKey, msg.sender, _amountValue);
            
        // transfer nft to new user 
        nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, msg.sender, tokenId);
        
        _platformFeeAddr.transfer(fee);
        payable(creator).transfer(royalityFee); 
        markets[uniqueKey].currentOwner.transfer(ownerShare);

        _userDashboard.setAmountRecord(creator,0,0,royalityFee,0); 
        _userDashboard.setAmountRecord(markets[uniqueKey].currentOwner,0,0,ownerShare,0); 
        _userDashboard.setAmountRecord(msg.sender,_amountValue,0,0,0); 
        
        // _userDashboard.setNftData(msg.sender, nftContractAddress, tokenId, price, maxPrice, 0,address(0), block.timestamp, endTime);

    }
    function buyTokenFixNFT(address nftContractAddress, uint256 tokenId, uint price) external virtual override nonReentrant {  
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        
        require(_erc20Token.allowance(msg.sender, address(this)) >= price, MP_NOT_APPROVED);

        (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract) 
        = fixedBuyingMethod(uniqueKey, msg.sender, price);
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
    function fixedBuyingMethod(bytes32 uniqueKey, address newOwner, uint _amountValue) private returns (uint, uint,uint,address, IERC721 )  {
        bytes32 uniKey= uniqueKey;
        require (_userDashboard.checkLogIn(newOwner), CREATE_ACC_OR_LOGIN); 
        require(markets[uniqueKey].orderStatus == OrderStatus.MarketOpen, "Market order is not opened or not existed" ); 
        require(markets[uniqueKey].orderType != OrderType.Auction, "To buy nft auction type buy with bidTokenNFT." ); 
        //Buying got done only with equal amount not less or higher amount will be accepted.
        require(markets[uniqueKey].askAmount == _amountValue, VALUE_NOT_MATCHED);

        IERC721 nftContract = IERC721(markets[uniqueKey].contractAddress);
        (uint256 royality, address creator) = nftContract.getRoyalityDetails(markets[uniqueKey].tokenId);

        //platform fee
        uint256 fee = getFeePercentage(_amountValue, _feePercent);
 
        // Royality 
        uint256 royalityFee = getFeePercentage(_amountValue, royality);
        
        uint256 ownerShare = _amountValue.sub(fee.add(royalityFee));
        
        // nft market close
        markets[uniKey].orderStatus = OrderStatus.MarketClosed;
        markets[uniKey].newOwner = newOwner;
        _userDashboard.setBuyNftData(newOwner, uniKey);

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
        require (_userDashboard.checkLogIn(msg.sender), CREATE_ACC_OR_LOGIN);

        
            if( markets[uniqueKey].maxAskAmount <= amount ) {
            markets[uniqueKey].currentHighestBid = amount;
            markets[uniqueKey].currentHighestBidder = msg.sender;

            (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract)= 
            auctionBuyingMethod(uniqueKey, amount, msg.sender);
                

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
    function auctionBuyingMethod(bytes32 _uniqueKey, uint _amountValue, address _newOwner) private  returns (uint, uint,uint,address, IERC721 )  {
        // bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenID);
        bytes32 uniqueKey = _uniqueKey;
       
        require(markets[uniqueKey].orderStatus == OrderStatus.MarketOpen, MARKET_ORDER_NOT_OPENED ); 

        IERC721 nftContract = IERC721(markets[uniqueKey].contractAddress);
        (uint256 royality, address creator) = nftContract.getRoyalityDetails(markets[uniqueKey].tokenId);

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
        _userDashboard.setAmountRecord(_newOwner,0,amount,0,0); 
        _userDashboard.setBuyNftData(_newOwner, uniqueKey);


        return (fee, royalityFee, ownerShare, creator, nftContract);
    }
    function auctionTokenTimeOver(address nftContractAddress, uint256 tokenId) external virtual override onlyOwner{
        bytes32 uniqueKey = getPrivateUniqueKey(nftContractAddress,tokenId);
        uint maxTime = markets[uniqueKey].auctionEndTime;
        uint currentTime = block.timestamp; 
        uint amount = markets[uniqueKey].currentHighestBid ;
        address successfulBidder = markets[uniqueKey].currentHighestBidder ;
        
        require (maxTime <= currentTime, BID_RUNNING);

        (uint fee,uint royalityFee,uint ownerShare, address creator, IERC721 nftContract)= 
            auctionBuyingMethod(uniqueKey, amount, successfulBidder);
       
        nftContract.safeTransferFrom(markets[uniqueKey].currentOwner, successfulBidder, tokenId);
    
        _erc20Token.transferFrom(successfulBidder, address(this), amount);
        _erc20Token.transfer(_platformFeeAddr, fee);
        _erc20Token.transfer(creator, royalityFee);
        _erc20Token.transfer(markets[uniqueKey].currentOwner, ownerShare); 
        console.log("You won the bid. you're the highest bidder.");
    }
}


    