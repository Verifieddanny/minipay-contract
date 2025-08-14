// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EduToken} from "./EduToken.sol";
import {ContentRegistry} from "./ContentRegistry.sol";

/*
 * Rewards and curation.
 */
contract EduRewards {
    EduToken public immutable token;
    ContentRegistry public immutable registry;

    uint256 public currentEpochId;
    uint64 public epochStart;
    uint64 public epochEnd;
    uint256 public emissionPerEpoch;
    uint256 public minStake;
    uint256 public lockPeriod;

    mapping(uint256 => mapping(uint256 => uint256)) public stakeByContent;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public userStake;
    mapping(address => uint256) public unlockedAt;
    mapping(address => uint256) public pendingRewards;

    bool public paused;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PARAM_ROLE = keccak256("PARAM_ROLE");
    mapping(bytes32 => mapping(address => bool)) internal roles;

    event EpochStarted(uint256 indexed epochId, uint64 start, uint64 end);
    event Curated(address indexed user, uint256 indexed epoch, uint256 indexed contentId, uint256 amount);
    event EpochFinalized(uint256 indexed epoch, uint256 totalReward);
    event Claimed(address indexed creator, uint256 amount);
    event Paused(bool paused);
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "access denied");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    constructor(
        address admin,
        EduToken _token,
        ContentRegistry _registry,
        uint64 initialEpochEnd,
        uint256 _emissionPerEpoch,
        uint256 _minStake,
        uint256 _lockPeriod
    ) {
        token = _token;
        registry = _registry;

        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PARAM_ROLE, admin);

        emissionPerEpoch = _emissionPerEpoch;
        minStake = _minStake;
        lockPeriod = _lockPeriod;

        currentEpochId = 1;
        epochStart = uint64(block.timestamp);
        epochEnd = initialEpochEnd;
        emit EpochStarted(currentEpochId, epochStart, epochEnd);
    }

    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        paused = false;
        emit Paused(false);
    }

    function curate(uint256 contentId, uint256 amount) external whenNotPaused {
        require(block.timestamp < epochEnd, "epoch ended");
        require(amount >= minStake, "amount too low");
        require(token.transferFrom(msg.sender, address(this), amount), "transfer failed");

        uint256 unlockTime = block.timestamp + lockPeriod;
        if (unlockTime > unlockedAt[msg.sender]) {
            unlockedAt[msg.sender] = unlockTime;
        }

        stakeByContent[currentEpochId][contentId] += amount;
        userStake[msg.sender][currentEpochId][contentId] += amount;

        emit Curated(msg.sender, currentEpochId, contentId, amount);
    }

    function finalizeEpoch(uint256[] calldata contentIds) external onlyRole(PARAM_ROLE) {
        require(block.timestamp >= epochEnd, "epoch not over yet");

        uint256 totalStakeForEpoch = 0;
        for (uint256 i = 0; i < contentIds.length; i++) {
            totalStakeForEpoch += stakeByContent[currentEpochId][contentIds[i]];
        }

        if (totalStakeForEpoch > 0 && emissionPerEpoch > 0) {
            for (uint256 i = 0; i < contentIds.length; i++) {
                uint256 cid = contentIds[i];
                uint256 stakeAmount = stakeByContent[currentEpochId][cid];
                if (stakeAmount == 0) continue;

                uint256 rewardAmount = (emissionPerEpoch * stakeAmount) / totalStakeForEpoch;

                (address creator,,,) = registry.contents(cid);
                pendingRewards[creator] += rewardAmount;

                token.mint(address(this), rewardAmount);
            }
        }

        emit EpochFinalized(currentEpochId, emissionPerEpoch);

        uint64 duration = epochEnd - epochStart;
        currentEpochId += 1;
        epochStart = uint64(block.timestamp);
        epochEnd = uint64(block.timestamp + duration);
        emit EpochStarted(currentEpochId, epochStart, epochEnd);
    }

    function claimRewards() external {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "nothing to claim");
        pendingRewards[msg.sender] = 0;
        require(token.transfer(msg.sender, amount), "transfer failed");
        emit Claimed(msg.sender, amount);
    }

    function withdrawStake(uint256 epochId, uint256 contentId, uint256 amount) external {
        require(block.timestamp >= unlockedAt[msg.sender], "still locked");
        uint256 staked = userStake[msg.sender][epochId][contentId];
        require(amount > 0 && staked >= amount, "insufficient stake");
        userStake[msg.sender][epochId][contentId] = staked - amount;
        stakeByContent[epochId][contentId] -= amount;
        require(token.transfer(msg.sender, amount), "transfer failed");
    }
}
