// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0; 

import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ERC721A NFT implementation
 * @author h_adnan
 * @notice Gas-optimized 10k NFT collection with Merkle tree whitelist based on ERC721A
 * 
 * 
 * Assumptions:
 * - Max supply would not be exceeded within presale phase
 * 
 *
 * ERROR LOG:
 * 00 :- Presale currently active
 * 01 :- Exceeds mint limit
 * 02 :- Presale has ended
 * 03 :- Must be whitelisted
 * 04 :- Invalid quantity 
 * 05 :- Caller must not be contract
 * 06 :- Caller must be admin
 * 07 :- Incorrect value sent
 * 08 :- Already minted in presale
 *
 */

contract NFTMerkle is ERC721A {

    // =============================================================
    //                            STORAGE
    // =============================================================
    
    uint256 public constant   COLLECTION_MAXIMUM_SUPPLY = 10000;

    uint256 public constant   PUBLIC_MINT_LIMIT_PER_WALLET = 5;

    uint256 public constant   PRESALE_MINT_LIMIT_PER_WALLET = 1;

    uint256 public constant   PRICE_PER_MINT = 0.05 ether;

    uint256 public immutable  PUBLIC_SALE_START_TIMESTAMP;


    bytes32 public constant MERKLE_ROOT = 0x326fe0d8a70ab934a7bf9d1323c6d87ee37bbe70079f82e72203b1e07c0c185c;


    address constant ADMIN_WALLET = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;


    mapping(address => uint256) private _publicMints;


    // =============================================================
    //                            MODIFIERS
    // =============================================================

    modifier mintable(uint256 quantity) {
        _checkSupply(quantity);
        _;
    }

    modifier notContract() {
        _checkCaller();
        _;
    }

    modifier publicSaleCompliance() {
        _checkPublicSaleCompliance();
        _;
    }

    modifier presaleCompliance() {
        _checkPresaleCompliance();
        _;
    }

    modifier auth() {
        _authenticate();
        _;
    }

    
    /**
     * @param initMintQuantity quantity of tokens to mint to the deployer
     *
     */
    constructor(uint256 initMintQuantity) ERC721A("NAME", "SYMBOL") {
        PUBLIC_SALE_START_TIMESTAMP = block.timestamp + 7 days;
        _mintERC2309(msg.sender, initMintQuantity);
    }

    // =============================================================
    //                        MINT FUNCTIONS
    // =============================================================

    /**
     * @notice Mints `quantity` tokens to the caller
     * @param quantity the quantity of tokens to be minted
     *
     *
     * Requirements:
     *
     * - Should only be used during public minting phase
     * - Should not be called by a contract
     * - `quantity` should be greater than zero
     * - Minting `quantity` should not exceed total supply or public mint max limit
     * - Sufficient eth needs to be sent with the transaction
     *
     *
     */
    function publicMint(
        uint256 quantity
    ) external payable notContract mintable(quantity) publicSaleCompliance {
        require(
            msg.value == PRICE_PER_MINT * quantity, 
            "07"
        );
        
        _mint(msg.sender, quantity);
    }

    /**
     * @notice Mints `PRESALE_MINT_LIMIT_PER_WALLET` tokens to the caller
     * @param merkleProof merkle proof to validate caller
     *
     *
     * Requirements:
     *
     * - Should only be used during presale minting phase
     * - Caller should not be a contract
     * - Caller should be whitelisted
     * - Sufficient eth needs to be sent with the transaction
     *
     *
     */
    function presaleMint(
        bytes32[] calldata merkleProof
    ) external payable notContract presaleCompliance {
        require(
            MerkleProof.verify(merkleProof, MERKLE_ROOT, keccak256(abi.encodePacked(msg.sender))),
            "03"
        );
        
        _mint(msg.sender, 1);
    }

    // =============================================================
    //                      PRIVATE HELPERS
    // =============================================================

    function _checkSupply(uint256 quantity) private view {
        require(
            quantity > 0 &&
            totalSupply() + quantity <= COLLECTION_MAXIMUM_SUPPLY, 
            "04"
        );
    }

    function _checkCaller() private view {
        require(
            msg.sender == tx.origin, 
            "05"
        );
    }

    function _checkPublicSaleCompliance() private {
        require(
            block.timestamp >= PUBLIC_SALE_START_TIMESTAMP, 
            "00"
        );
        
        unchecked { _publicMints[msg.sender]++; }

        require(
            _publicMints[msg.sender] <= PUBLIC_MINT_LIMIT_PER_WALLET, 
            "01"
        );
    }

    function _checkPresaleCompliance() private view {
        require(
            block.timestamp < PUBLIC_SALE_START_TIMESTAMP, 
            "02"
        );
        require(
            msg.value == PRICE_PER_MINT, 
            "07"
        );
        require(
            _numberMinted(msg.sender) == 0,
             "08"
        );
    }

    function _authenticate() private view {
        require(
            msg.sender == ADMIN_WALLET, 
            "06"
        );
    }
    
    /**
     * NOTE: Replace with appropriate base uri of collection
     *
    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://________/";
    }

    // =============================================================
    //                      ADMIN ACCESS ONLY
    // =============================================================


    /**
     * @notice Mints `quantity` tokens to the admin
     * @param quantity the quantity of tokens to mint
     *
     * Requirements:
     *
     * - `quantity` should be greater than zero
     * - Minting `quantity` should not exceed total supply
     *
     */
    function adminMint(uint256 quantity) external payable auth mintable(quantity) {
        _mint(msg.sender, quantity);
    }   

    /**
     * @notice Transfers eth accumulated in this contract to the admin
     *
     */
    function adminWithdraw() external payable auth {
        payable(msg.sender).transfer(address(this).balance);
    }

}
