// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CyclicSale
/// @notice Endless, timestamp-driven sale rounds. Allocation and settlement are added in Stage 3.
contract CyclicSale is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Phase { Upcoming, Participation, Claim }

    struct Round {
        uint256 totalCommitted;
        uint256 participantsCount;
        address[] participants;
        mapping(address => uint256) committed;
    }

    IERC20 public immutable token;
    IERC20 public immutable paymentToken;
    uint256 public immutable price;
    uint256 public immutable basePool;
    uint256 public immutable genesisTime;
    uint256 public immutable participationDuration;
    uint256 public immutable claimDuration;
    uint256 public immutable minCommit;
    uint256 public immutable maxCommitPerWallet;
    address public immutable treasury;

    bool public paused;
    mapping(uint256 => Round) private rounds;

    error InvalidConfiguration();
    error ZeroCommit();
    error SaleNotActive(Phase currentPhase);
    error SalePaused();
    error CommitBelowMinimum(uint256 minimum, uint256 newTotal);
    error CommitAboveMaximum(uint256 maximum, uint256 newTotal);
    error InvalidPagination();

    event Committed(uint256 indexed round, address indexed user, uint256 amount, uint256 userTotal);
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    constructor(
        address token_,
        address paymentToken_,
        uint256 price_,
        uint256 basePool_,
        uint256 genesisTime_,
        uint256 participationDuration_,
        uint256 claimDuration_,
        uint256 minCommit_,
        uint256 maxCommitPerWallet_,
        address treasury_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            token_ == address(0) || paymentToken_ == address(0) || price_ == 0 || basePool_ == 0 ||
            genesisTime_ == 0 || participationDuration_ == 0 || claimDuration_ == 0 ||
            minCommit_ == 0 || maxCommitPerWallet_ < minCommit_ || treasury_ == address(0)
        ) revert InvalidConfiguration();

        token = IERC20(token_);
        paymentToken = IERC20(paymentToken_);
        price = price_;
        basePool = basePool_;
        genesisTime = genesisTime_;
        participationDuration = participationDuration_;
        claimDuration = claimDuration_;
        minCommit = minCommit_;
        maxCommitPerWallet = maxCommitPerWallet_;
        treasury = treasury_;
    }

    function cycleDuration() public view returns (uint256) {
        return participationDuration + claimDuration;
    }

    function currentRound() public view returns (uint256) {
        if (block.timestamp < genesisTime) return 0;
        return (block.timestamp - genesisTime) / cycleDuration();
    }

    function phase() public view returns (Phase) {
        if (block.timestamp < genesisTime) return Phase.Upcoming;
        uint256 offset = (block.timestamp - genesisTime) % cycleDuration();
        return offset < participationDuration ? Phase.Participation : Phase.Claim;
    }

    function commit(uint256 amount) external nonReentrant {
        _commit(amount);
    }

    function commitWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // A permit can be front-run; continue if the allowance is already present.
        try IERC20Permit(address(paymentToken)).permit(msg.sender, address(this), amount, deadline, v, r, s) {} catch {}
        _commit(amount);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function roundInfo(uint256 round)
        external
        view
        returns (
            uint256 participationStart,
            uint256 participationEnd,
            uint256 claimEnd,
            uint256 pool,
            uint256 totalCommitted,
            uint256 participantsCount
        )
    {
        participationStart = genesisTime + round * cycleDuration();
        participationEnd = participationStart + participationDuration;
        claimEnd = participationEnd + claimDuration;
        pool = basePool;
        Round storage saleRound = rounds[round];
        totalCommitted = saleRound.totalCommitted;
        participantsCount = saleRound.participantsCount;
    }

    function getParticipants(uint256 round, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory users, uint256[] memory amounts)
    {
        Round storage saleRound = rounds[round];
        if (limit == 0 || offset > saleRound.participantsCount) revert InvalidPagination();
        uint256 end = offset + limit;
        if (end > saleRound.participantsCount) end = saleRound.participantsCount;
        users = new address[](end - offset);
        amounts = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            address user = saleRound.participants[i];
            users[i - offset] = user;
            amounts[i - offset] = saleRound.committed[user];
        }
    }

    function _commit(uint256 amount) internal {
        if (amount == 0) revert ZeroCommit();
        if (paused) revert SalePaused();
        Phase currentPhase = phase();
        if (currentPhase != Phase.Participation) revert SaleNotActive(currentPhase);

        uint256 round = currentRound();
        Round storage saleRound = rounds[round];
        uint256 newTotal = saleRound.committed[msg.sender] + amount;
        if (newTotal < minCommit) revert CommitBelowMinimum(minCommit, newTotal);
        if (newTotal > maxCommitPerWallet) revert CommitAboveMaximum(maxCommitPerWallet, newTotal);

        if (saleRound.committed[msg.sender] == 0) {
            saleRound.participants.push(msg.sender);
            saleRound.participantsCount++;
        }
        saleRound.committed[msg.sender] = newTotal;
        saleRound.totalCommitted += amount;
        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Committed(round, msg.sender, amount, newTotal);
    }
}
