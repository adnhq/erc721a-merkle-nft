// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0; 

import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";

/**
 * @title ERC721A NFT implementation
 * @author h_adnan
 * @notice Gas-optimized 10k NFT collection implementation based on ERC721A
 * 
 * 
 * Assumptions:
 * - Max supply would not be exceeded within presale phase
 * 
 *
 * ERROR LOG:
 * e01 :- Presale is active
 * e02 :- You have reached your mint limit
 * e03 :- Presale has ended
 * e04 :- You do not have access
 * e05 :- Invalid quantity 
 * e06 :- Caller can not be contract
 * e07 :- Caller must be admin
 * e08 :- Insufficient mint price sent
 *
 */

contract NFTOne is ERC721A {

    // =============================================================
    //                            STORAGE
    // =============================================================

    uint256 public constant COLLECTION_MAXIMUM_SUPPLY = 10000;
    uint256 public constant PUBLIC_MINT_LIMIT_PER_WALLET = 5;
    uint256 public constant PRESALE_MINT_LIMIT_PER_WALLET = 1;
    uint256 public constant PRICE_PER_MINT = 0.05 ether;

    address constant ADMIN_WALLET = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    string private _baseTokenURI;
    bool public    presale = true;

    mapping(address => uint256) private _whitelists;
    mapping(address => uint256) private _publicMints;


    modifier mintable(uint256 quantity) {
        _checkSupply(quantity);
        _;
    }

    modifier notContract() {
        _checkCaller();
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
    constructor(uint256 initMintQuantity) ERC721A("Very Epic Collection", "VEC") {
        _mintERC2309(msg.sender, initMintQuantity);
    }

    // =============================================================
    //                        MINT OPERATIONS
    // =============================================================

    /**
     * @notice Mints `quantity` tokens to the caller
     * @param quantity the quantity of tokens to be minted
     *
     * Requirements:
     *
     * - Should only be used during public minting phase
     * - Caller should not be a contract
     * - `quantity` should be greater than zero
     * - Minting `quantity` should not exceed total supply or public mint max limit
     * - Sufficient eth needs to be sent with the transaction
     *
     *
     * Excess eth sent with the transaction is refunded to caller
     *
     */
    function publicMint(uint256 quantity) external payable notContract mintable(quantity) {
        require(!presale, "e01");
            
        unchecked {
            _publicMints[msg.sender] += quantity;
        }

        require(_publicMints[msg.sender] <= PUBLIC_MINT_LIMIT_PER_WALLET, "e02");

        _mint(msg.sender, quantity);

        _retVal(quantity * PRICE_PER_MINT);
    }

    /**
     * @notice Mints `PRESALE_MINT_LIMIT_PER_WALLET` tokens to the caller
     *
     * Requirements:
     *
     * - Should only be used during presale minting phase
     * - Caller should not be a contract
     * - Caller should be whitelisted
     * - Sufficient eth needs to be sent with the transaction
     * 
     *
     * Excess eth sent with the transaction is refunded to caller
     *
     */
    function presaleMint() external payable notContract {
        require(presale, "e03");

        require(
            _whitelists[msg.sender] == 1,
            "e04"
        );

        _whitelists[msg.sender] = 0;

        _mint(msg.sender, PRESALE_MINT_LIMIT_PER_WALLET);

        _retVal(PRICE_PER_MINT);

    }

    

    // =============================================================
    //                     PRIVATE HELPERS
    // =============================================================

    function _checkSupply(uint256 quantity) private view {
        require(
            quantity > 0 &&
            totalSupply() + quantity <= COLLECTION_MAXIMUM_SUPPLY, 
            "e05"
        );
    }

    function _checkCaller() private view {
        require(
            msg.sender == tx.origin, 
            "e06"
        );
    }

    function _retVal(uint amountRequired) private {
        require(msg.value >= amountRequired, "e04");

        if(msg.value > amountRequired) {
            (bool ok, ) = payable(msg.sender).call{value: msg.value - amountRequired}("");
            require(ok);
        }
            
    }   

    function _authenticate() private view {
        require(
            msg.sender == ADMIN_WALLET, 
            "e07"
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
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
    function adminMint(uint quantity) external payable auth mintable(quantity) {
        _mint(msg.sender, quantity);
    }   

    /**
     * @notice Ends presale and begins public sale phase
     *
     */
    function enablePublicMint() external auth {
        presale = false;
    }

    /**
     * @notice Whitelist addresses for presale
     * @notice users list of addresses to be whitelisted
     *
     */
    function whitelist(address[] calldata users) external payable auth {
        uint256 len = users.length;

        for(uint256 i; i < len; ) {
            _whitelists[users[i]] = 1;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Set base URI for collection
     * @param baseURI base URI of the collection 
     *
     */
    function setBaseURI(string calldata baseURI) external auth {
        _baseTokenURI = baseURI;
    }

    /**
     * @notice Transfers eth accumulated in this contract to the admin
     *
     */
    function withdraw() external payable auth {
        (bool ok, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(ok);
    }

}
