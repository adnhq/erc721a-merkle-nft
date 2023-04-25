// SPDX-License-Identifier: MIT

pragma solidity >=0.8.18; 

import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";
import "https://github.com/vectorized/solady/blob/main/src/utils/MerkleProofLib.sol";

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

    error AllowlistMintOn();
    error PublicMintOn();
    error ExceedsMintLimit();
    error AccessDenied();
    error ExceedsMaxSupply();
    error IncorrectValue();

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    /// @notice Sample values

    bytes32 private constant _MERKLE_ROOT = 0x326fe0d8a70ab934a7bf9d1323c6d87ee37bbe70079f82e72203b1e07c0c185c;

    uint256 public constant  PUBLIC_SALE_START_TIMESTAMP = 1677650400;
    uint256 public constant  MAXIMUM_SUPPLY = 10000;
    uint256 public constant  PUBLIC_SALE_MINT_LIMIT = 5;
    uint256 public constant  PRICE_PER_MINT = 0.05 ether;
    
    address private constant _ADMIN = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;


    // =============================================================
    //                            MODIFIERS
    // =============================================================


    modifier notContract() {
        _checkCallerIsNotContract();
        _;
    }

    /**
     * @param initMintQuantity quantity of tokens to mint to the deployer
     *
     */
    constructor(uint256 initMintQuantity) 
    ERC721A("NAME", "SYMBOL") { _mintERC2309(msg.sender, initMintQuantity); }

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
    {
        if(block.timestamp < PUBLIC_SALE_START_TIMESTAMP) {
            _revert(AllowlistMintOn.selector);
        }

        if(msg.value != PRICE_PER_MINT * quantity) {
            _revert(IncorrectValue.selector);
        }

        if(_totalMinted() + quantity > MAXIMUM_SUPPLY) {
            _revert(ExceedsMaxSupply.selector);
        }

        if(_numberMinted(msg.sender) + quantity > (_getAux(msg.sender) == 0 ? PUBLIC_SALE_MINT_LIMIT : PUBLIC_SALE_MINT_LIMIT + 1)) {
            _revert(ExceedsMintLimit.selector);
        } 

        _mint(msg.sender, quantity);
    }

    /**
     * @notice Mints one token to the caller
     * @param proof merkle proof to validate caller
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
    function allowlistMint(bytes32[] calldata proof) 
        external 
        payable  
        notContract
    {
        if(block.timestamp >= PUBLIC_SALE_START_TIMESTAMP) {
            _revert(PublicMintOn.selector);
        }

        if(msg.value != PRICE_PER_MINT) {
            _revert(IncorrectValue.selector);
        }

        if(_getAux(msg.sender) > 0) {
            _revert(ExceedsMintLimit.selector);
        }

        if(!MerkleProofLib.verifyCalldata(
            proof, 
            _MERKLE_ROOT, 
            keccak256(bytes.concat(keccak256(abi.encode(msg.sender))))
        )) {
            _revert(AccessDenied.selector);
        }
        
        
        _setAux(msg.sender, 1);

        _mint(msg.sender, 1);
    }

    // =============================================================
    //                      PRIVATE HELPERS
    // =============================================================

    function _checkCallerIsNotContract() private view {
        bytes4 errorSelector = AccessDenied.selector;
        assembly {
            if iszero(eq(caller(), origin())) {
                mstore(0x00, errorSelector)
                revert(0x00, 0x04)
            }
        }
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
        return "ipfs://************************/";
    }

    // =============================================================
    //                      ADMIN ACCESS ONLY
    // =============================================================  

    /**
     * @notice Transfers eth accumulated in this contract to the admin
     *
     */
    function collectMintingFee() external payable {
        bool success;
        bytes4 errorSelector = AccessDenied.selector;

        assembly {
            if iszero(eq(caller(), _ADMIN)) {
                mstore(0x00, errorSelector)
                revert(0x00, 0x04)
            }

            success := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
        }

        require(success);
    }

}
