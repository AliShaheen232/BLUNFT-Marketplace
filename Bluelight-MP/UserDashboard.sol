//SPDX-License-Identifier: MIT

pragma solidity =0.8.4;
import "./IERC721.sol";
import "./IWaterMelon.sol";
import "./IUserDashboard.sol";

contract UserDashboard is IUserDashboard{

    event LoggingIn (address indexed user, uint timeStamp);
    event LoggingOut (address indexed user, uint timeStamp);
    event SignUp (address indexed user, string username, uint timeStamp);
    
    struct MyNFT{
        address contractAddress;
        uint256 tokenId;
        address owner;
        string ipfs;
    }
    struct User{
        string userName;
        bool userExisted;
        uint creationTime;
        bool loggedIn;
        string profilePic;
    }
    struct AmountRecord{
        uint curAmountSpent;
        uint tokenAmountSpent;
        uint curAmountEarned;
        uint tokenAmountEarned;
    }
    IWaterMelon private waterMelonAddr;
    mapping (bytes32 => MyNFT) public myNFTs;
    mapping (address => bytes32[]) public uniKeysMapping;
    ////// profile 
    mapping (address => User) private users;
    mapping (string => address) public userNameToAddress; //bytes32, 16 work same here as string 
    mapping (address => AmountRecord) public addressToAmountRecord;

    constructor(address wmAddr){
        waterMelonAddr = IWaterMelon(wmAddr);
    }
    function getPrivateUniqueKey(address nftContractAddress, uint256 tokenId) internal pure returns (bytes32 NFTUniKey){
        return keccak256(abi.encodePacked(nftContractAddress, tokenId));
    }
    function setNftData(address owner, address nftContractAddress, uint256 tokenId, string memory iPFS) external virtual override{
        
        bytes32 uniKey = getPrivateUniqueKey(nftContractAddress, tokenId); 
        
        myNFTs[uniKey].contractAddress = nftContractAddress;
        myNFTs[uniKey].tokenId = tokenId;
        myNFTs[uniKey].owner = owner;
        myNFTs[uniKey].ipfs = iPFS;
        uniKeysMapping[owner].push(uniKey);  
    }
    function getNftdata(bytes32 _uniKey) external virtual override view returns(address nftContractAddress, uint256 tokenId, address owner, string memory iPFS){
        bytes32 uniKey = _uniKey;
        
        return ( myNFTs[uniKey].contractAddress,
        myNFTs[uniKey].tokenId,
        myNFTs[uniKey].owner,
        myNFTs[uniKey].ipfs
        );
    }
    function getUniKeysMapping(address ownerOfNfts) external view returns(bytes32[] memory){
        return uniKeysMapping[ownerOfNfts];
    }
    ////////////////////// User Profile Section /////////////////////
    function logIn() virtual override external {
        require (users[msg.sender].userExisted, "user not existed, create account first.");
        require (!users[msg.sender].loggedIn, "you're already loggedIn.");

        users[msg.sender].loggedIn = true;
        emit LoggingIn(msg.sender, block.timestamp);
    } 
    function checkLogIn(address _userAddr) external virtual override view returns(bool){  
        return users[_userAddr].loggedIn;
    }
    function logOut() external virtual override{
        require (users[msg.sender].loggedIn, "you're not loggedIn.");
        users[msg.sender].loggedIn = false;
        emit LoggingOut(msg.sender, block.timestamp); 
        
    }
    function signUp(string memory _userName) external virtual override{
        require (!users[msg.sender].userExisted, "user existed.");
        require (userNameToAddress[_userName] == address(0), "user name existed.");

        users[msg.sender].userName = _userName;
        users[msg.sender].userExisted = true;
        users[msg.sender].creationTime = block.timestamp;
        users[msg.sender].loggedIn = true;
        userNameToAddress[_userName] = msg.sender;
        // logIn();we can call direct this method in signup() method, but making loggedIn "true" here.  
        emit SignUp (msg.sender, _userName, block.timestamp);        
    }
    function setProfilePic(string memory iPFS) external {
        require (users[msg.sender].loggedIn, "Login to your account, to set profile pic.");
        users[msg.sender].profilePic = iPFS;
    }
    function getProfilePic() external view returns(string memory ipfs){
        return users[msg.sender].profilePic;
    }
    function checkUser() external virtual override view returns(string memory){
        require(users[msg.sender].loggedIn, "create account first or logIn to your account.");
        return users[msg.sender].userName;
    }
    function updateUser(string memory _userName) external virtual override{
        require (users[msg.sender].loggedIn, "Log in to your account.");
        require (userNameToAddress[_userName] == address(0), "user name existed.");

        string memory name = users[msg.sender].userName;
        delete userNameToAddress[name];
        userNameToAddress[_userName] = msg.sender;

        users[msg.sender].userName = _userName;
    }
    function deleteUser() external virtual override returns(bool){
        require (users[msg.sender].userExisted, "user not existed.");
        string memory name = users[msg.sender].userName;
        delete userNameToAddress[name];
        delete users[msg.sender];
        return true;
    }
    function setAmountRecord(address user, uint curAmountSpent, uint tokenAmountSpent, uint curAmountEarned, uint tokenAmountEarned) external virtual override{
        addressToAmountRecord[user].curAmountSpent += curAmountSpent;
        addressToAmountRecord[user].tokenAmountSpent += tokenAmountSpent;
        addressToAmountRecord[user].curAmountEarned += curAmountEarned;
        addressToAmountRecord[user].tokenAmountEarned += tokenAmountEarned;
    }
    function userAmountDetail(address user) external virtual override view 
        returns(uint currencyEarned, uint earnedToken, uint currencySpent, uint tokenSpent){
        return(
            addressToAmountRecord[user].curAmountEarned, addressToAmountRecord[user].tokenAmountEarned, 
            addressToAmountRecord[user].curAmountSpent,  addressToAmountRecord[user].tokenAmountSpent
        );
    }
}

 
















    