// SPDX-License-Identifier: MIT
 pragma solidity 0.8.7;
 
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INFT {
    function mint(address to) external;
}

contract HellvenINO is  
      OwnableUpgradeable,
      ReentrancyGuardUpgradeable,
      PausableUpgradeable
    {
    INFT public nft;

    uint256 public nTotalJoined;
    uint256 public currentStage;
    mapping(uint256 => Stage) public stages; // stage_id => State struct
    mapping(uint256 => mapping(address => bool)) public stageWhiteList; // stage_id => address => whitelist?
    mapping(uint256 => uint256) public nStateJoined; // stage_id => joined quantity
    mapping(uint256 => mapping(address => uint256)) public stageBought; // stage_id => address => bought

    event Join(address user, uint256 state, uint256 quantity, uint256 amount);

    struct Stage {
        address paymentToken;
        uint256 amount;
        uint256 quantity;
        uint256 maxBuy;
        uint256 startTime;
        uint256 endTime;
        bool isWhitelist;
    }

    modifier isNotContract(address user) {
        require(_checkIsNotCallFromContract());
        require(_isNotContract(user));
        _;
    }

    modifier openToBuy() {
        require(
            block.timestamp >= stages[currentStage].startTime,
            "HeroINO::not buy time yet"
        );
        require(
            block.timestamp <= stages[currentStage].endTime,
            "HeroINO::closed to buy"
        );
        _;
    }
 
    function initialize(address _nft)
        external
        initializer
    {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
        nft = INFT(_nft);
    }

    function joinINO(uint256 _quantity)
        external
        payable
        isNotContract(_msgSender())
        whenNotPaused
        openToBuy
    {
        address sender = _msgSender();
        Stage memory _state = stages[currentStage];

        /* CHECK */
        require(isJoinable(sender, _quantity), "HeroINO::user cannot join");

        if(_state.paymentToken ==address(0)){
           require(
            msg.value >= _state.amount * _quantity,
            "HeroINO::transfer Coin failed"
           );
        }
        else{
           IERC20(_state.paymentToken).transferFrom(sender, address(this), _state.amount * _quantity);
        }
        
        /* INTERACTION */
        for (uint256 i = 0; i < _quantity; i++) {
            nft.mint(sender);
        }

        /* EFFECT */
        nTotalJoined += _quantity;
        stageBought[currentStage][sender] += _quantity;
        nStateJoined[currentStage] += _quantity;

        emit Join(msg.sender, currentStage, _quantity, msg.value);
    }

    /// SALE CONFIG
    function updateWhitelist(uint256 _state, address[] calldata _whitelists)
        external
        onlyOwner
    {
        for (uint256 i; i < _whitelists.length; i++) {
            stageWhiteList[_state][_whitelists[i]] = true;
        }
    }

    function removeWhitelist(uint256 _state, address[] calldata _whitelists)
        external
        onlyOwner
    {
        for (uint256 i; i < _whitelists.length; i++) {
            stageWhiteList[_state][_whitelists[i]] = false;
        }
    }

    function setNFT(address _nft) external onlyOwner {
        nft = INFT(_nft);
    }
    

    function setStage(
        address paymentToken,
        uint256 stageId,
        uint256 amount,
        uint256 quantity,
        uint256 maxBuy,
        uint256 startTime,
        uint256 endTime,
        bool isWhitelist
    ) external onlyOwner {
        stages[stageId] = Stage(
            paymentToken,
            amount,
            quantity,
            maxBuy,
            startTime,
            endTime,
            isWhitelist
        );
    }

    function setCurrentStage(uint256 stageId) external onlyOwner {
        currentStage = stageId;
    }

    function withdrawBalance(address token, address to) external onlyOwner {
      if( token ==address(0)){
          require(address(this).balance > 0, "HeroINO: Balance must be greater zero");
          payable(to).transfer(address(this).balance);
      }
      else{
          require(IERC20(token).balanceOf(address(this)) > 0, "HeroINO: Balance must be greater zero");
          IERC20(token).transfer(to, IERC20(token).balanceOf(address(this)));
      }
    }

    /// ADMINISTATION
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// CONDITIONAL CHECKS

    function isJoinable(address buyer, uint256 _quantity)
        public
        view
        returns (bool)
    {
        if (currentStage == 0 || paused()) {
            return false;
        }

        Stage memory _state = stages[currentStage];

        // check NFT quantity for Stage
        if (nStateJoined[currentStage] + _quantity > _state.quantity) {
            return false;
        }

        // check max buy for each address
        if (
            _state.maxBuy == 0 ||
            stageBought[currentStage][buyer] + _quantity <= _state.maxBuy
        ) {
            // check Stage is whitelist or not
            if (_state.isWhitelist) {
                return stageWhiteList[currentStage][buyer];
            } else {
                return true;
            }
        }

        return false;
    }

    function _isNotContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size == 0);
    }

    function _checkIsNotCallFromContract() internal view returns (bool) {
        if (msg.sender == tx.origin) {
            return true;
        } else {
            return false;
        }
    }
}
