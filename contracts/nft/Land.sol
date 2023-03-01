// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Land is AccessControlEnumerable, ERC721Enumerable, ERC721Burnable {
    event BaseURIChanged(string uri);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _uri;

    uint256 public currentId;

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

    constructor(
        string memory name,
        string memory symbol,
        string memory uri
    ) ERC721(name, symbol) {
        _uri = uri;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
    }

    function setBaseURI(string memory uri) public virtual onlyAdmin {
        require(bytes(uri).length > 0, "Hellven: uri is invalid");

        _uri = uri;

        emit BaseURIChanged(uri);
    }

    function mint(address to) public virtual onlyMiner {
        _mint(to, ++currentId);
    }

    function mintBatch(address[] memory accounts) public virtual onlyMiner {
        uint256 length = accounts.length;

        require(length > 0, "Hellven: array is invalid");

        uint256 id = currentId;

        for (uint256 i = 0; i < length; i++) {
            _mint(accounts[i], ++id);
        }

        currentId = id;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}