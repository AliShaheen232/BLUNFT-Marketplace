//SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "./IERC721.sol";
import "./IWaterMelon.sol";
import "./IUserDashboard.sol";
import "./Helper.sol";

contract UserDashboard is IUserDashboard, Helper{

    // make nft delete methods, 

    //////////////////// Errors
    string constant CREATE_ACCOUNT = "WMU-1";
    string constant CREATE_ACC_OR_LOGIN = "WMU-2";
    string constant ALREADY_LOGIN = "WMU-3";
    string constant USER_EXISTED = "WMU-4";
    string constant USER_NOT_EXISTED = "WMU-5";
    string constant USER_NAME_EXISTED = "WMU-6"; 
    
    event LoggingIn (address indexed user, uint timeStamp);
    event LoggingOut (address indexed user, uint timeStamp);
    event SignUp (address indexed user, string username, uint timeStamp);
    
    IWaterMelon private waterMelonAddr;
    mapping (bytes32 => MyNFT) public myNFTs;
    mapping (address => bytes32[]) public uniKeysMapping;
    mapping (NftCategory => bytes32[]) public nftCatWise;
    mapping (address => mapping (NftCategory => bytes32[])) public userNftCatWise;
    ////// profile 
    mapping (address => User) private users;
    mapping (string => address) public userNameToAddress; //bytes32, 16 work same here as string 
    mapping (address => AmountRecord) public addressToAmountRecord;

    enum NftCategory{
        AVATAR, PICTURE, GENERATIVE_ART, ART, COLLECTIBLES, GAMIFIED, OTHER
    }
    struct MyNFT{
        string nftName;
        address contractAddress;
        uint256 tokenId;
        address owner;
        string ipfs;
        NftCategory nftCategory;
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

    constructor(address wmAddr){
        waterMelonAddr = IWaterMelon(wmAddr);
    }
    function setNft(string memory _name, address nftContractAddress, uint256 tokenId, string memory iPFS) external virtual override{
        require (users[msg.sender].loggedIn, CREATE_ACC_OR_LOGIN);

        bytes32 uniKey = getPrivateUniqueKey(nftContractAddress, tokenId); 
        myNFTs[uniKey].nftName = _name;
        myNFTs[uniKey].contractAddress = nftContractAddress;
        myNFTs[uniKey].tokenId = tokenId;
        myNFTs[uniKey].owner = msg.sender;
        myNFTs[uniKey].ipfs = iPFS; 
        uniKeysMapping[msg.sender].push(uniKey);  
    }
    function setNftCat(address nftContractAddress, uint256 tokenId, NftCategory nftCat) external {
        bytes32 uniKey = getPrivateUniqueKey(nftContractAddress, tokenId); 
        require (users[msg.sender].loggedIn && myNFTs[uniKey].owner == msg.sender, CREATE_ACC_OR_LOGIN);

        myNFTs[uniKey].nftCategory = nftCat;
        nftCatWise[nftCat].push(uniKey);
        userNftCatWise[msg.sender][nftCat].push(uniKey);
    }
    function setBuyNftData(address owner, bytes32 uniKey) external virtual override{
        
        myNFTs[uniKey].owner = owner;
        
        uniKeysMapping[owner].push(uniKey);  
    }    
    /////////////////////// Get Methods ////////////////////////////
    function getAllNftCatWise(NftCategory nftCat) external view returns(bytes32[] memory){
        return nftCatWise[nftCat];
    }
    function getUserNftCatWise(NftCategory nftCat) external view returns(bytes32[] memory){
        return userNftCatWise[msg.sender][nftCat];
    }
    function getNftCategories() external pure returns(string memory,string memory,string memory,string memory,string memory,string memory,string memory) {
        return ("AVATAR", "PICTURE", "GENERATIVE_ART", "ART", "COLLECTIBLES", "GAMIFIED", "OTHER");
    }
    function getNftWithBytes32(bytes32 _uniKey) external virtual override view 
        returns(string memory _name, address nftContractAddress, uint256 tokenId, address owner, string memory iPFS){
        bytes32 uniKey = _uniKey;
        
        return (myNFTs[uniKey].nftName, myNFTs[uniKey].contractAddress, myNFTs[uniKey].tokenId, myNFTs[uniKey].owner,
        myNFTs[uniKey].ipfs);
    }
    function getNft(address _nftContractAddress, uint256 _tokenId) external virtual override view 
        returns(bytes32 uniKey, address nftContractAddress, uint tokenId, string memory name, address owner, string memory iPFS){
        
        bytes32 _uniKey = getPrivateUniqueKey(_nftContractAddress, _tokenId); 

        return (_uniKey, myNFTs[_uniKey].contractAddress, myNFTs[_uniKey].tokenId, myNFTs[_uniKey].nftName, myNFTs[_uniKey].owner, myNFTs[_uniKey].ipfs);
    }
    function getUniKeysMapping(address ownerOfNfts) external view returns(bytes32[] memory){
        return uniKeysMapping[ownerOfNfts];
    }
    function getProfilePic() external view returns(string memory ipfs){
        return users[msg.sender].profilePic;
    }
    ////////////////////// User Profile Section /////////////////////
    function logIn() virtual override external {
        require (users[msg.sender].userExisted, CREATE_ACCOUNT);
        require (!users[msg.sender].loggedIn, ALREADY_LOGIN);

        users[msg.sender].loggedIn = true;
        emit LoggingIn(msg.sender, block.timestamp);
    } 
    function checkLogIn(address _userAddr) external virtual override view returns(bool){  
        return users[_userAddr].loggedIn;
    }
    function logOut() external virtual override{
        require (users[msg.sender].loggedIn, CREATE_ACC_OR_LOGIN);
        users[msg.sender].loggedIn = false;
        emit LoggingOut(msg.sender, block.timestamp); 
        
    }
    function signUp(string memory _userName) external virtual override{
        require (!users[msg.sender].userExisted, USER_EXISTED);
        require (userNameToAddress[_userName] == address(0), USER_NAME_EXISTED);

        users[msg.sender].userName = _userName;
        users[msg.sender].userExisted = true;
        users[msg.sender].creationTime = block.timestamp;
        users[msg.sender].loggedIn = true;
        userNameToAddress[_userName] = msg.sender;
        // logIn();we can call direct this method in signup() method, but making loggedIn "true" here.  
        emit SignUp (msg.sender, _userName, block.timestamp);        
    }
    function setProfilePic(string memory iPFS) external {
        require (users[msg.sender].loggedIn, CREATE_ACC_OR_LOGIN);
        users[msg.sender].profilePic = iPFS;
    }
    function checkUser() external virtual override view returns(string memory){
        require(users[msg.sender].loggedIn, CREATE_ACC_OR_LOGIN);
        return users[msg.sender].userName;
    }
    function updateUser(string memory _userName) external virtual override{
        require (users[msg.sender].loggedIn, CREATE_ACC_OR_LOGIN);
        require (userNameToAddress[_userName] == address(0), USER_NAME_EXISTED);

        string memory name = users[msg.sender].userName;
        delete userNameToAddress[name];
        userNameToAddress[_userName] = msg.sender;

        users[msg.sender].userName = _userName;
    }
    function deleteUser() external virtual override returns(bool){
        require (users[msg.sender].userExisted, USER_NOT_EXISTED);
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