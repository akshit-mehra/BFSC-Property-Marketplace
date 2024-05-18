//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Marketplace is ReentrancyGuard {

    address public owner;
    uint public propertyCount;
    uint public inspectorCount;

    constructor() {
        owner = msg.sender;
    }

    struct Property {
        uint id;
        uint tokenId;
        uint price;
        uint deposit;
        ERC721 nft;
        address payable seller;
        address payable buyer;
        bool onMarket; // if caution money is deposited then [false]
        bool validDocuments;
    }

    mapping(uint => Property) public properties;
    mapping(uint => address) public approvedInspectors; // record of all the approved land inspectors


   
    

    // Modifers and their funcrtions
    function _onlyBuyer(uint _propertyID) private view {
        require(
            msg.sender == properties[_propertyID].buyer,
            "Only buyer can call this method"
        );
    }

    function _onlySeller(uint _propertyID) private view {
        require(
            msg.sender == properties[_propertyID].seller,
            "Only seller can call this method"
        );
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only owner can call this method");
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyInspector(uint _inspectorId) private view {
        require(
            _inspectorId > 0 && _inspectorId <= inspectorCount,
            "inspector ID is invalid"
        );
        require(
            msg.sender == approvedInspectors[_inspectorId],
            "Only inspector can call this method"
        );
    }

    modifier onlyBuyer(uint256 _propertyID) {
        _onlyBuyer(_propertyID);
        _;
    }

    modifier onlySeller(uint _propertyID) {
        _onlySeller(_propertyID);
        _;
    }

   

    modifier onlyInspector(uint _inspectorId) {
        _onlyInspector(_inspectorId);
        _;
    }


    // return the total balance of the contract
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function addInspector(address _inspector) public onlyOwner returns (uint) {
        inspectorCount++;
        approvedInspectors[inspectorCount] = _inspector;
        return inspectorCount;
    }


    // fallback function used if no function is specified while sending ether
    // fallback() external payable {
    //     revert("No function specified");
    // }

    function listProperty(
        uint _price,
        ERC721 _nft,
        uint _tokenId
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than 0");
        propertyCount++;
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        properties[propertyCount] = Property({
            id: propertyCount,
            tokenId: _tokenId,
            price: _price,
            deposit: 0,
            nft: _nft,
            seller: payable(msg.sender),
            buyer: payable(address(0)),
            onMarket: false,
            validDocuments: false
        });
    }

    function verifyDocuments(
        uint _propertyId,
        uint _inspectorId,
        bool _result
    ) external onlyInspector(_inspectorId) {
         require(
            _propertyId > 0 && _propertyId <= propertyCount,
            "Property does not exist"
        );
        properties[_propertyId].validDocuments = _result;
        properties[_propertyId].onMarket = _result;
    }

    // buyer puts a depost that is 15% of the total price
    function depositDeposit(uint _propertyId) external payable nonReentrant {
        require(
            _propertyId > 0 && _propertyId <= propertyCount,
            "Property does not exist"
        );
        require(
            msg.value * 100 >= properties[_propertyId].price * 15,
            "Minimum deposit not covered"
        );
        require(properties[_propertyId].onMarket, "Property not on the market");
        require(
            properties[_propertyId].validDocuments,
            "Seller's property documents are not valid"
        );
        properties[_propertyId].onMarket = false;
        properties[_propertyId].deposit = msg.value;
        properties[_propertyId].buyer = payable(msg.sender);
    }

    // finalizing sale of property
    // pre requisite: buyer must have deposited caution money
    //  and property must be on market and property must have valid documents
    // delists the property from market and transfers the ownership of the property to the buyer
    function finalizeSale(
        uint _propertyId
    )
        external
        payable
        onlyBuyer(_propertyId)
    {

         require(_propertyId > 0 && _propertyId <= propertyCount, "Property does not exist");
        require( msg.value >= properties[_propertyId].price - properties[_propertyId].deposit,"Insufficient funds to cover property price and gas fee");
        require( properties[_propertyId].deposit * 100 >= properties[_propertyId].price * 15, "Deposit not paid");

        require(properties[_propertyId].validDocuments,"Property documesnts are not valid");

        properties[_propertyId].seller.transfer(properties[_propertyId].price);
        properties[_propertyId].nft.transferFrom(
            address(this),
            msg.sender,
            properties[_propertyId].tokenId
        );

        properties[_propertyId].deposit = 0;
        properties[_propertyId].seller = payable(msg.sender);
        properties[_propertyId].buyer = payable(address(0));
        properties[_propertyId].onMarket = false;
        properties[_propertyId].validDocuments = false;
    }

    //  cancel deal from buyer side and seller keeps all the money
    function cancelSaleBuyer (uint _propertyId) external nonReentrant  onlyBuyer(_propertyId) {

        require(_propertyId > 0 && _propertyId <= propertyCount, "Property does not exist");
        Property storage currProperty = properties[_propertyId];


        // require the property to be on market
        require(currProperty.onMarket == false, "no available seller");

        // property should have a deposit
        require(currProperty.deposit > 0, "No depost to return");
        require(currProperty.buyer != address(0), "No buyer for the property");

        properties[_propertyId].deposit = 0;
        properties[_propertyId].buyer = payable(address(0));
        properties[_propertyId].onMarket = true;

        // seller gets the deposit put down
        currProperty.seller.transfer(currProperty.deposit);

    }

    // cancel deal from seller side and return the deposit
    function cancelSaleSeller (uint _propertyId) external nonReentrant  onlySeller(_propertyId) {

        require(_propertyId > 0 && _propertyId <= propertyCount, "Property does not exist");
        Property storage currProperty = properties[_propertyId];


        // require the property to be on market
        require(currProperty.onMarket == false, "no available buyer");

        // property should have a deposit
        require(currProperty.deposit > 0, "No depost to return");
        require(currProperty.buyer != address(0), "No buyer for the property");

        properties[_propertyId].deposit = 0;
        properties[_propertyId].buyer = payable(address(0));
        properties[_propertyId].onMarket = true;

        currProperty.buyer.transfer(currProperty.deposit);

    }



    // delist the property and transfer nft back to seller
    function delist (uint _propertyId) external nonReentrant onlySeller(_propertyId) {

        require(_propertyId > 0 && _propertyId <= propertyCount, "Property does not exist");
        require(properties[_propertyId].onMarket , "Property not on market");


        // mark property not on market and transfer the NFT back to the seller from the contract
        properties[_propertyId].onMarket = false;
        properties[_propertyId].nft.transferFrom( address(this),properties[_propertyId].seller , properties[_propertyId].tokenId);
    }

    // change price by seller
    function changePrice(uint _propertyId, uint _newPrice) external nonReentrant onlySeller(_propertyId) {

        require(_propertyId > 0 && _propertyId <= propertyCount, "Property does not exist");
        require(properties[_propertyId].onMarket , "Property not on market");
        require(properties[_propertyId].deposit == 0, "deposit already put down");

        // now documents will need to be checked again as we need new appraisal
        properties[_propertyId].validDocuments = false;
        properties[_propertyId].price = _newPrice;

    }



    
}
