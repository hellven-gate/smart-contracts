// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../utils/Signature.sol";

contract GenesisNFT is
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Signature for bytes32;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /**
     * @dev The base URI for all NFT.
     */
    string public __baseURI;

    uint256 public currentId;

    mapping(uint256 => uint256) public rarities; //0.Not reveal yet | 1.S | 2.SR | 3.SSR | 4.UR

    event Reveal(address user, uint256 tokenId, uint256 rarity);

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Genesis: must be admin role"
        );
        _;
    }

    modifier onlySigner() {
        require(
            hasRole(SIGNER_ROLE, _msgSender()),
            "Genesis: must be signer role"
        );
        _;
    }

    function initialize() external initializer {
        __ERC721_init("Hellven Genesis", "HELLGEN");
        __ERC721Pausable_init();
        __ERC721Enumerable_init();
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SIGNER_ROLE, _msgSender());
        __baseURI = "https://metadata.hellven.io/genesis/";
    }

    function mint(address to) public virtual onlySigner {
        _safeMint(to, ++currentId);
    }

    function reveal(
        uint256 _tokenId,
        uint256 _rarity,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        require(_exists(_tokenId), "Genesis: tokenId not exists");
        require(rarities[_tokenId] == 0, "Genesis: tokenId revealed");
        _verifySignerSignature(
            keccak256(abi.encodePacked(_msgSender(), _tokenId, _rarity)),
            _signature
        );

        rarities[_tokenId] = _rarity;

        emit Reveal(_msgSender(), _tokenId, _rarity);
    }

    function setBaseURI(string memory newBaseURI) external onlyAdmin {
        __baseURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    function _verifySignerSignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view {
        bytes32 prefixed = _messageHash.prefixed();
        address singer = prefixed.recoverSigner(_signature);

        require(hasRole(SIGNER_ROLE, singer), "Genesis: Signature invalid");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        virtual
        override(
            ERC721Upgradeable,
            ERC721PausableUpgradeable,
            ERC721EnumerableUpgradeable
        )
    {
        ERC721Upgradeable._beforeTokenTransfer(from, to, tokenId);
        ERC721PausableUpgradeable._beforeTokenTransfer(from, to, tokenId);
        ERC721EnumerableUpgradeable._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            AccessControlEnumerableUpgradeable,
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
