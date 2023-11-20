// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";



contract NFTMarketplace is Ownable {
    // using SafeMath for uint256;
    string  img="https://github.com/gajera-ankita/Images/tree/main/";
    using Counters for Counters.Counter;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemsCount;
    uint256  royaltyfee= 1;
    uint256 public LISTING_FEE = 1 ether;
    uint256 public  royaltyamount;
    // The NFT contract
    ERC721 public nftContract;
     mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(uint256 => address) public highestBidder;
    
    struct Auction {
            uint256  nftId;
            uint256 highestBid;
            address highestBidder;
            uint256 endTime;
   }
    struct imageInfo {
            uint Id; 
            bool _isavailableforsale;
            bool _isAvailableForAuction;
            string imgContent;
            uint nftPrice;
            address nftOwner;
    }
     imageInfo[] public imageList;

    mapping(uint256 => Auction) public auctions;
    uint256 public nextAuctionId = 1;

    event AuctionCreated(uint256 auctionId, uint256 tokenId, address seller);
    event NFTListed(uint256 tokenId, bool isavailableforsale);
    event NFTSold(uint256 tokenId, address buyer, uint256 price);
 
    constructor(address _nftContractAddress) {
        nftContract = ERC721(_nftContractAddress);

    }

     function uploadImage(uint nftId,uint imgContent, uint nftPrice,bool isavailableforauction) public onlyOwner {
        // address towner = msg.sender; // The address of the caller becomes the "towner"
        string memory str = Strings.toString(imgContent);
        
        string memory imgPath = string(abi.encodePacked(img, str, ".jpg"));
        uint256 nftpriceEth=nftPrice*10**18 wei;
        
        imageList.push(imageInfo(nftId,false, isavailableforauction,imgPath, nftpriceEth,msg.sender));
         nftContract._mint(msg.sender, nftId);
       
    }

    function startAuction(uint256 tokenId, uint256 startingBid, uint256 duration) external {
         Auction storage auction = auctions[tokenId];
            require(imageList[auction.nftId]._isAvailableForAuction==true);
            require(imageList[tokenId].nftOwner == msg.sender, "You don't own this NFT");
            require(imageList[tokenId]._isavailableforsale == false, "NFT is already listed for sale");
        
            uint256 auctionEndTime = block.timestamp + duration;

            auctions[nextAuctionId] = Auction({
                nftId:tokenId,
                highestBid: startingBid,
                highestBidder: address(0),
                endTime: auctionEndTime
            });

            imageList[tokenId]._isavailableforsale = true;
            _itemsCount.increment();

            emit AuctionCreated(nextAuctionId, tokenId, msg.sender);

            nextAuctionId++;
    }
     function placeBid(uint256 auctionId) external payable {
            Auction storage auction = auctions[auctionId];
            require(auction.endTime > block.timestamp, "Auction has ended");
            require(msg.value > auction.highestBid, "Bid must be higher than the current highest bid");

            
            if (auction.highestBidder != address(0)) {
                payable(auction.highestBidder).transfer(auction.highestBid);
            }

            auction.highestBid = msg.value;
            auction.highestBidder = msg.sender;
     }
    function endAuction(uint256 auctionId) external onlyOwner {
            Auction storage auction = auctions[auctionId];
          
            require(auction.endTime <= block.timestamp, "Auction is still ongoing");

            address seller = imageList[auction.nftId] .nftOwner;
            address buyer = auction.highestBidder;
            uint256 price = auction.highestBid;

            (nftContract)._transfer(seller, buyer, imageList[auction.nftId].Id);
            nftContract.setApprovalForAll(buyer, true);

            payable(seller).transfer(price);

          
            imageList[auctionId]._isavailableforsale = false;
            _itemsSold.increment();

            
}



    function listNFTForSale(uint256 tokenId) external payable {
        require(imageList[tokenId]._isavailableforsale == false,"NFT is listed for sale");
        require(imageList[tokenId].nftOwner == msg.sender,"You don't own this NFT");
        if(msg.sender!=owner()){
            require(msg.value==LISTING_FEE,"Insufficient funds to Listing the NFT");
           
             payable(owner()).transfer(LISTING_FEE);
        }
        imageList[tokenId]._isavailableforsale = true;
        _itemsCount.increment();
        emit NFTListed(tokenId, imageList[tokenId]._isavailableforsale);
    }

  
    function buyNFT(uint256 tokenId) external payable {
        uint256 price = imageList[tokenId].nftPrice;
        require(imageList[tokenId]._isavailableforsale == true,"NFT is not listed for sale");
        require(msg.value >= price, "Insufficient funds to buy the NFT");
        require(imageList[tokenId]._isAvailableForAuction== false, "Nft is  in an auction");
        
        address seller = nftContract.ownerOf(imageList[tokenId].Id);
        address buyer = msg.sender;
         imageList[tokenId]._isAvailableForAuction = false;
         royaltyamount=calculateFee(price,royaltyfee);
         payable(owner()).transfer(royaltyamount);
         price -= royaltyamount;

         (nftContract)._transfer(seller, buyer,imageList[tokenId].Id);
         nftContract.setApprovalForAll(buyer, true);
        _itemsSold.increment();
        imageList[tokenId].nftOwner = buyer;   
         payable(seller).transfer(price);
        
        
        imageList[tokenId]._isavailableforsale = false;
        
        emit NFTSold(tokenId, buyer, price);
    }
    function updateprice(uint pricenft,uint nftid)public {
        require(nftContract.ownerOf(imageList[nftid].Id) == msg.sender, "You do not own this NFT");
        imageList[nftid].nftPrice=pricenft*10**18 wei;
    }
    // Withdraw funds from the contract (for the owner)
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    function getItemsCount() public view returns(uint256) {
        return _itemsCount.current();
    }
    function getItemsSold() public view returns(uint256) {
        return _itemsSold.current();
    }
    function calculateFee( uint256 amount,uint256 royaltyFee) private pure  returns (uint256) {
        return amount* (royaltyFee)/(10**2);
    }
    function CurrentTime()public view returns (uint256){
        return block.timestamp;
    }
}
