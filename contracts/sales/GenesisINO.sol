// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IGenesisNFT {
    function mint(address to) external;
}

struct Stage{
    uint256 amount;
    uint256 quantity;
    uint256 maxBuy;
    uint256 startTime;
    uint256 endTime;
    bool isWhitelist;
}

contract GenesisINO is Ownable, Pausable {
    IGenesisNFT public genesisNFT;

    uint256 public nTotalJoined;
    uint256 public currentStage;
    mapping (uint256 => Stage) public stages; // stage_id => State struct
    mapping (uint256 => mapping (address => bool)) public stageWhiteList; // stage_id => address => whitelist?
    mapping (uint256 => uint256) public nStateJoined; // stage_id => joined quantity
    mapping (uint256 => mapping (address => uint256)) public stageBought; // stage_id => address => bought
    
    event Join(address user, uint256 state, uint256 quantity, uint256 amount);

    modifier isNotContract(address user) {
        require(_checkIsNotCallFromContract());
		require(_isNotContract(user));
		_;
	}

    modifier openToBuy() {
        require(block.timestamp >= stages[currentStage].startTime, "GenesisINO::not buy time yet");
        require(block.timestamp <= stages[currentStage].endTime, "GenesisINO::closed to buy");
        _;
    }

    constructor(address _genesisNFT) {
        genesisNFT = IGenesisNFT(_genesisNFT);
    }

    function joinINO(uint256 _quantity) external isNotContract(_msgSender()) whenNotPaused openToBuy payable {
        address sender = _msgSender();
        Stage memory _state = stages[currentStage];

        /* CHECK */
        require (isJoinable(sender, _quantity), "GenesisINO::user cannot join");
        require (msg.value >= _state.amount * _quantity, "GenesisINO::transfer Coin failed");
        
        /* INTERACTION */
        for (uint256 i = 0; i < _quantity; i++) {
            genesisNFT.mint(sender);
        }

        /* EFFECT */
        nTotalJoined += _quantity;
        stageBought[currentStage][sender] += _quantity;
        nStateJoined[currentStage] += _quantity;

        emit Join(msg.sender, currentStage, _quantity, msg.value);
    }

     /// SALE CONFIG
    function updateWhitelist(uint256 _state, address [] calldata _whitelists) external onlyOwner {
        for (uint i; i < _whitelists.length; i++) {
            stageWhiteList[_state][_whitelists[i]] = true;
        }
	}

    function removeWhitelist(uint256 _state, address [] calldata _whitelists) external onlyOwner {
        for (uint i; i < _whitelists.length; i++) {
            stageWhiteList[_state][_whitelists[i]] = false;
        }
	}

    function setGenesisNFT(address _genesisNFT) external onlyOwner {
        genesisNFT = IGenesisNFT(_genesisNFT);
	}

    function setStage(uint stageId, uint256 amount, uint256 quantity, uint256 maxBuy, uint256 startTime, uint256 endTime, bool isWhitelist) external onlyOwner {
        stages[stageId] = Stage(amount, quantity, maxBuy, startTime, endTime, isWhitelist);
	}

    function setCurrentStage(uint stageId) external onlyOwner {
        currentStage = stageId;
	}

    function withdrawBalance(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

     /// ADMINISTATION
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// CONDITIONAL CHECKS

    function isJoinable(address buyer, uint256 _quantity) public view returns (bool) {
        if(currentStage == 0 || paused()) {
            return false;
        }
        
        Stage memory _state = stages[currentStage];

        // check NFT quantity for Stage
        if(nStateJoined[currentStage] + _quantity > _state.quantity) {
            return false;
        }

        // check max buy for each address
        if(
            _state.maxBuy == 0 ||
            stageBought[currentStage][buyer] + _quantity <= _state.maxBuy
        ){

            // check Stage is whitelist or not
            if(_state.isWhitelist) {
                return stageWhiteList[currentStage][buyer];
            } else {
                return true;
            }  
        }
 
        return false; 
    }

    function _isNotContract(address _addr) internal view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size == 0);
    }

    function _checkIsNotCallFromContract() internal view returns (bool){
	    if (msg.sender == tx.origin){
		    return true;
	    } else{
	        return false;
	    }
	}
}