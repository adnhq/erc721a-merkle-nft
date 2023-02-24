// SPDX-License-Identifier: MIT

pragma solidity =0.8.18; 

import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ERC721A NFT implementation
 * @author h_adnan
 * @notice Gas-optimized 10k ERC721A NFT collection with Merkle Tree whitelist
 * 
 * Assumptions:
 * - Max supply would not be exceeded within allowlist mint phase
 *
 */

contract NFTMerkle is ERC721A {

    // =============================================================
    //                           ERRORS
    // =============================================================

    error AllowlistMintActive();

    error PublicSaleActive();

    error ExceedsMintLimit();

    error AccessDenied();

    error InvalidQuantity();

    error CallerIsContract();

    error AllowlistMintClaimed();

    error IncorrectValueSent();

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    /// @notice Sample values

    bytes32 private constant _MERKLE_ROOT = 0x326fe0d8a70ab934a7bf9d1323c6d87ee37bbe70079f82e72203b1e07c0c185c;


    uint256 public constant  PUBLIC_SALE_START_AT = 1677650400;

    uint256 public constant  MAXIMUM_SUPPLY = 10000;

    uint256 public constant  PUBLIC_MINT_LIMIT = 5;

    uint256 public constant  PRICE_PER_MINT = 50000000000000000;

    
    address private constant _ADMIN = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;


    // =============================================================
    //                            MODIFIERS
    // =============================================================


    modifier notContract() {
        _checkCallerIsNotContract();
        _;
    }

    modifier pubCompliance(uint256 quantity) {
        _checkPublicSaleCompliance(quantity);
        _;
    }

    modifier preCompliance() {
        _checkPresaleCompliance();
        _;
    }


    /**
     * @param initMintQuantity quantity of tokens to mint to the deployer
     *
     */
    constructor(uint256 initMintQuantity) ERC721A("NAME", "SYMBOL") {
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
    function mint(uint256 quantity) 
        external 
        payable 
        notContract 
        pubCompliance(quantity) 
    {
        _mint(msg.sender, quantity);
    }

    /**
     * @notice Mints one token to the caller
     * @param proofs merkle proofs to validate caller
     *
     *
     * Requirements:
     *
     * - Should only be used during presale minting phase
     * - Caller should be whitelisted
     * - Sufficient eth needs to be sent with the transaction
     *
     *
     */
    function allowlistMint(bytes32[] calldata proofs) 
        external 
        payable  
        preCompliance 
    {

        if(!MerkleProof.verifyCalldata(
            proofs, 
            _MERKLE_ROOT, 
            keccak256(bytes.concat(keccak256(abi.encode(msg.sender))))
        )) _revert(AccessDenied.selector);
        
        
        _setAux(msg.sender, 1);

        _mint(msg.sender, 1);
    }

    // =============================================================
    //                      PRIVATE HELPERS
    // =============================================================

    function _checkCallerIsNotContract() private view {
        if(msg.sender != tx.origin) _revert(CallerIsContract.selector);
    }

    function _checkPublicSaleCompliance(uint256 quantity) private view {
        if(block.timestamp < PUBLIC_SALE_START_AT) _revert(AllowlistMintActive.selector);

        if(quantity == 0 || _totalMinted() + quantity > MAXIMUM_SUPPLY) _revert(InvalidQuantity.selector);

        if(msg.value != PRICE_PER_MINT * quantity) _revert(IncorrectValueSent.selector);

        uint256 lim = _getAux(msg.sender) == 0 ? PUBLIC_MINT_LIMIT : PUBLIC_MINT_LIMIT + 1;

        if(_numberMinted(msg.sender) + quantity > lim) _revert(ExceedsMintLimit.selector);
    }

    function _checkPresaleCompliance() private view {
        if(block.timestamp >= PUBLIC_SALE_START_AT) _revert(PublicSaleActive.selector);

        if(msg.value != PRICE_PER_MINT) _revert(IncorrectValueSent.selector);
        
        if(_getAux(msg.sender) == 1) _revert(AllowlistMintClaimed.selector);
    }

    /**
     * @dev Should return base url of collection metadata
     * NOTE: Replace with appropriate base uri of collection before use
     */
    function _baseURI() 
        internal 
        view 
        virtual 
        override 
        returns 
    (string memory) {
        return "ipfs://*************************************/";
    }

    // =============================================================
    //                      ADMIN ACCESS ONLY
    // =============================================================  

    /**
     * @notice Transfers eth accumulated in this contract to the admin
     *
     */
    function collectMintingFee() external payable {
        if(msg.sender != _ADMIN) _revert(AccessDenied.selector);

        payable(msg.sender).transfer(address(this).balance);
    }

}
