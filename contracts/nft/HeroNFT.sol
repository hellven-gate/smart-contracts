// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "../utils/Signature.sol";

contract HeroNFT is
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Signature for bytes32;

    event BaseURIChanged(string uri);

    event LockTimeChanged(uint256 locktime);

    event WhitelistERC721Changed(address addr, bool status);

    event LockTransfer(
        uint256 indexed tokenId,
        uint256 timeLock,
        uint256 duration
    );

    event Reveal(address user, uint256 tokenId, uint256 rarity);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    string private _uri;

    uint256 public currentId;

    uint256 public TIME_LOCK_TRANSFER;

    mapping(uint256 => bool) public revealed;

    mapping(uint256 => uint256) public lastTimeTransfer;

    mapping(address => bool) public whitelistAddresses;

    mapping(uint256 => address) public lastSenders;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Hellven: must be admin role"
        );
        _;
    }

    modifier onlyMiner() {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Hellven: must be minter role"
        );
        _;
    }

    function initialize(string memory name, string memory symbol)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        __Context_init();
        __ERC721_init(name, symbol);
        __ERC721Pausable_init();
        __AccessControl_init();
        __AccessControlEnumerable_init();
        __ERC721Enumerable_init();
        __ReentrancyGuard_init();
        TIME_LOCK_TRANSFER = 3600 * 48;
        whitelistAddresses[address(0)] = true;
        _uri = "https://meta.hellven.io/hero/";
    }

    function setBaseURI(string memory uri) public virtual onlyAdmin {
        require(bytes(uri).length > 0, "Hellven: uri is invalid");

        _uri = uri;

        emit BaseURIChanged(uri);
    }

    function setLockTime(uint256 locktime) public onlyAdmin {
        TIME_LOCK_TRANSFER = locktime;

        emit LockTimeChanged(locktime);
    }

    function addWhitelistAddressTransfer(address addr, bool status)
        public
        onlyAdmin
    {
        whitelistAddresses[addr] = status;

        emit WhitelistERC721Changed(addr, status);
    }

    function mint(address to) public virtual onlyMiner {
        ++currentId;
        _mint(to, currentId);
    }

    function mint(address to, bool isReveal) public virtual onlyMiner {
        ++currentId;
        _mint(to, currentId);
        revealed[currentId] = isReveal;
    }

    function mintBatch(address[] memory accounts) public virtual onlyMiner {
        uint256 length = accounts.length;

        require(length > 0, "Hellven: array is invalid");

        uint256 id = currentId;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = ++id;
            _mint(accounts[i], tokenId);
        }

        currentId = id;
    }

    function reveal(
        uint256 _tokenId,
        uint256 _rarity,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        address sender = _msgSender();
        require(ownerOf(_tokenId) == sender, "Hellven: must be owner of token");
        require(!revealed[_tokenId], "Hellven: tokenId revealed");
        _verifySignerSignature(
            keccak256(abi.encodePacked(sender, _tokenId, _rarity)),
            _signature
        );

        revealed[_tokenId] = true;

        emit Reveal(_msgSender(), _tokenId, _rarity);
    }

    function isLock(uint256 tokenId) public view returns (bool) {
        return lastTimeTransfer[tokenId] + TIME_LOCK_TRANSFER > block.timestamp;
    }

    function remainLockTime(uint256 tokenId) public view returns (uint256) {
        if (lastTimeTransfer[tokenId] + TIME_LOCK_TRANSFER > block.timestamp) {
            return
                lastTimeTransfer[tokenId] +
                TIME_LOCK_TRANSFER -
                block.timestamp;
        }

        return 0;
    }

    function burn(uint256 _tokenId) public {
        address owner = ERC721Upgradeable.ownerOf(_tokenId);

        require(owner == _msgSender(), "Hellven: must be owner");

        _burn(_tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
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
        require(
            !revealed[tokenId] ||
                whitelistAddresses[to] ||
                (whitelistAddresses[from] && lastSenders[tokenId] == to) ||
                lastTimeTransfer[tokenId] + TIME_LOCK_TRANSFER <=
                block.timestamp,
            "Hellven: token is lock transfer"
        );

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable) {
        bool lock = true;
        if (
            !revealed[tokenId] ||
            from == address(0) ||
            whitelistAddresses[to] ||
            (whitelistAddresses[from] && lastSenders[tokenId] == to)
        ) {
            lock = false;
        }

        lastSenders[tokenId] = from;
        if (lock) {
            lastTimeTransfer[tokenId] = block.timestamp;
            emit LockTransfer(tokenId, block.timestamp, TIME_LOCK_TRANSFER);
        }
    }

    function _verifySignerSignature(
        bytes32 _messageHash,
        bytes memory _signature
    ) internal view {
        bytes32 prefixed = _messageHash.prefixed();
        address singer = prefixed.recoverSigner(_signature);

        require(hasRole(SIGNER_ROLE, singer), "Genesis: Signature invalid");
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
