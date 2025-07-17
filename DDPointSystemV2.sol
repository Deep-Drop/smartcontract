// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DDPointSystemV2 is Ownable, Pausable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct User {
        uint256 points;
        uint256 lastHourlyCheckIn;
        uint256 lastDailyCheckIn;
        uint256 lastWeeklyCheckIn;
    }

    struct Data {
        uint256 totalUsers;
        uint256 totalPoints;
        address[] users;
        mapping(address => uint256) userPoints;
        mapping(uint256 => uint256) countPoints;
        mapping(uint256 => uint256) countPointsSS;
        mapping(address => uint256) lastHourlyCheckInForSS;
        mapping(address => uint256) lastDailyCheckInForSS;
        mapping(address => uint256) lastWeeklyCheckInForSS;
        mapping(address => uint256[3]) userCheckInCounts;
    }

    struct Record {
        uint256 timestamp;
        uint8 checkInType;
    }

    IERC20 public ptsToken;
    uint256 public ptsTokenTotRate = 1;
    uint8 public ptsTokenDecimals = 18;
    bool public pausedDepositPTS = true; 
    uint256 public totalDepositedPointsAll;
    mapping(address => User) private users;
    EnumerableSet.AddressSet private participants;
    mapping(uint256 => Data) public ssData;
    mapping(address => uint256) private totalUsedPointsForUser;
    mapping(uint256 => mapping(address => Record[])) private checkInHistorySS;
    mapping(address => uint256) private depositedPoints;

    uint256 public hourlyReward;
    uint256 public dailyReward;
    uint256 public weeklyReward;
    uint256 public hourlyRewardCount;
    uint256 public dailyRewardCount;
    uint256 public weeklyRewardCount;
    uint256 public hourlyRewardCountSS;
    uint256 public dailyRewardCountSS;
    uint256 public weeklyRewardCountSS;
    uint256 public hourlyReductionCount;
    uint256 public dailyReductionCount;
    uint256 public weeklyReductionCount;
    uint256 private constant HOUR = 1 hours;
    uint256 private constant DAY = 1 days;
    uint256 private constant WEEK = 7 days;
    uint256 public reductionCycle;
    uint256 public lastReductionTime;
    uint256 public nextReductionTime;
    uint256 public totalUsedPoints;
    uint256 public totalAllPoints;

    uint256 public SS = 1;
    string public DDPoint_VERSION = "v2";

    event PointsEarned(address indexed user, uint256 points, string checkInType, uint256 timeStamp);
    event PointsUsed(address indexed user, uint256 points, string usedInType, uint256 timeStamp);
    event PointsReset(address indexed user);
    event PointsReduced(uint256 newHourlyReward, uint256 newDailyReward, uint256 newWeeklyReward);
    event PointsDeposited(address indexed user, uint256 tokenAmount, uint256 pointAmount);

    constructor(
        uint256 _hourlyReward,
        uint256 _dailyReward,
        uint256 _weeklyReward,
        uint256 _reductionCycle
    ) Ownable(msg.sender) {
        reductionCycle = _reductionCycle;
        lastReductionTime = block.timestamp;
        nextReductionTime = lastReductionTime + reductionCycle;
        hourlyReward = _hourlyReward;
        dailyReward = _dailyReward;
        weeklyReward = _weeklyReward;
    }

    function autoReduceSystem() internal {
        if (block.timestamp >= lastReductionTime + reductionCycle) {
            hourlyReward = hourlyReward * 95 / 100;
            dailyReward = dailyReward * 95 / 100;
            weeklyReward = weeklyReward * 95 / 100;
            hourlyReductionCount++;
            dailyReductionCount++;
            weeklyReductionCount++;
            lastReductionTime = block.timestamp;
            nextReductionTime = lastReductionTime + reductionCycle;
            emit PointsReduced(hourlyReward, dailyReward, weeklyReward);
        }
    }

    function collectInHourly() external whenNotPaused nonReentrant { autoReduceSystem();
        require(block.timestamp >= users[msg.sender].lastHourlyCheckIn + HOUR, "You cannot collect Hourly points at this time.");
        users[msg.sender].points += hourlyReward;
        users[msg.sender].lastHourlyCheckIn = block.timestamp;
        participants.add(msg.sender);

        ssData[SS].userPoints[msg.sender] += hourlyReward;
        ssData[SS].countPoints[hourlyRewardCount++];
        ssData[SS].countPointsSS[0] = hourlyRewardCountSS += 1;
        ssData[SS].lastHourlyCheckInForSS[msg.sender] = block.timestamp;
        ssData[SS].userCheckInCounts[msg.sender][0]++;
        checkInHistorySS[SS][msg.sender].push(Record({timestamp: block.timestamp, checkInType: 0}));

        totalAllPoints += hourlyReward;
        emit PointsEarned(msg.sender, hourlyReward, "Hourly", block.timestamp);
    }

    function checkInDaily() external whenNotPaused nonReentrant { autoReduceSystem();
        require(block.timestamp >= users[msg.sender].lastDailyCheckIn + DAY, "You cannot check-in Daily points at this time.");
        users[msg.sender].points += dailyReward;
        users[msg.sender].lastDailyCheckIn = block.timestamp;
        participants.add(msg.sender);

        ssData[SS].userPoints[msg.sender] += dailyReward;
        ssData[SS].countPoints[dailyRewardCount++];
        ssData[SS].countPointsSS[1] = dailyRewardCountSS += 1;
        ssData[SS].lastDailyCheckInForSS[msg.sender] = block.timestamp;
        ssData[SS].userCheckInCounts[msg.sender][1]++;
        checkInHistorySS[SS][msg.sender].push(Record({timestamp: block.timestamp, checkInType: 1}));

        totalAllPoints += dailyReward;
        emit PointsEarned(msg.sender, dailyReward, "Daily", block.timestamp);
    }

    function checkInWeekly() external whenNotPaused nonReentrant { autoReduceSystem();
        require(block.timestamp >= users[msg.sender].lastWeeklyCheckIn + WEEK, "You cannot check-in Weekly points at this time.");
        users[msg.sender].points += weeklyReward;
        users[msg.sender].lastWeeklyCheckIn = block.timestamp;
        participants.add(msg.sender);

        ssData[SS].userPoints[msg.sender] += weeklyReward;
        ssData[SS].countPoints[weeklyRewardCount++];
        ssData[SS].countPointsSS[2] = weeklyRewardCountSS += 1;
        ssData[SS].lastWeeklyCheckInForSS[msg.sender] = block.timestamp;
        ssData[SS].userCheckInCounts[msg.sender][2]++;
        checkInHistorySS[SS][msg.sender].push(Record({timestamp: block.timestamp, checkInType: 2}));

        totalAllPoints += weeklyReward;
        emit PointsEarned(msg.sender, weeklyReward, "Weekly", block.timestamp);
    }

    function getUserCountPoints(address _user, uint256 _ss) external view returns (uint256 hourly, uint256 daily, uint256 weekly) {
        uint256[3] storage counts = ssData[_ss].userCheckInCounts[_user];
        return (counts[0], counts[1], counts[2]);
    }

    function getUserCountPointStats(address _user, uint256 _ss, uint256 _start, uint256 _end) external view returns (uint256 hourly, uint256 daily, uint256 weekly) {
        Record[] storage records = checkInHistorySS[_ss][_user];
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].timestamp >= _start && records[i].timestamp <= _end) {
                if (records[i].checkInType == 0) {
                    hourly++;
                } else if (records[i].checkInType == 1) {
                    daily++;
                } else if (records[i].checkInType == 2) {
                    weekly++;
                }
            }
        }
    }

    function usedPoints(uint256 _amount) external nonReentrant {
        require(users[msg.sender].points >= _amount, "Insufficient points");
        users[msg.sender].points -= _amount;
        ssData[SS].userPoints[msg.sender] -= _amount;
        totalUsedPoints += _amount;
        totalUsedPointsForUser[msg.sender] += _amount;
        emit PointsUsed(msg.sender, _amount, "Deducted", block.timestamp);
    }

    function movePoints(uint256 _fromSSToSS) external nonReentrant {
        require(_fromSSToSS < SS, "Cannot move from current or future SS");
        uint256 pointsToMove = ssData[_fromSSToSS].userPoints[msg.sender];
        require(pointsToMove > 0, "No points to move");
        ssData[_fromSSToSS].totalPoints -= pointsToMove;
        ssData[_fromSSToSS].userPoints[msg.sender] = 0;
        ssData[SS].userPoints[msg.sender] += pointsToMove;
        ssData[SS].totalPoints += pointsToMove;
        users[msg.sender].points += pointsToMove;
        emit PointsEarned(msg.sender, pointsToMove, "MigratedFromSS", block.timestamp);
    }

    function depositPTS(uint256 _tokenAmount) external nonReentrant {
        require(!pausedDepositPTS, "Deposit PTS is paused");
        require(_tokenAmount > 0, "Amount must be > 0");
        require(_tokenAmount % (10 ** ptsTokenDecimals) == 0, "Amount must be a whole number");
        require(ptsToken.transferFrom(msg.sender, address(this), _tokenAmount), "Transfer failed");
        uint256 points = (_tokenAmount * ptsTokenTotRate) / (10 ** ptsTokenDecimals);
        users[msg.sender].points += points;
        ssData[SS].userPoints[msg.sender] += points;
        depositedPoints[msg.sender] += points;
        totalDepositedPointsAll += points;
        totalAllPoints += points;
        participants.add(msg.sender);
        emit PointsDeposited(msg.sender, _tokenAmount, points);
    }

    function toggleDepositPTS() external onlyOwner {
        pausedDepositPTS = !pausedDepositPTS;
    }

    function setDepositPTS(address _tokenAddress, uint256 _rate, uint8 _decimals) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_rate > 0, "Rate must be > 0");
        ptsToken = IERC20(_tokenAddress);
        ptsTokenTotRate = _rate;
        ptsTokenDecimals = _decimals;
    }

    function getDepositPTS(address _user) external view returns (uint256) {
        return depositedPoints[_user];
    }

    function getTotalDepositedPointsAll() external view returns (uint256) {
        return totalDepositedPointsAll;
    }

    function getTotalUsedPoints() external view returns (uint256) {
        return totalUsedPoints;
    }
    
    function getTotalAllPoints() external view returns (uint256) {
        return totalAllPoints;
    }
    
    function getPoints(address _user) external view returns (uint256) {
        return users[_user].points;
    }

    function getUsedPointsForUserSS(address _user) external view returns (uint256) {
        return totalUsedPointsForUser[_user];
    }

    function getTotalPointsForUserSS_NotToUsed(address _user) external view returns (uint256) {
        return users[_user].points + totalUsedPointsForUser[_user];
    }

    function getPointsAccLastTime(address _user) external view returns (uint256 lastHourlyCheckIn, uint256 lastDailyCheckIn, uint256 lastWeeklyCheckIn) {
        User storage user = users[_user];
        return (user.lastHourlyCheckIn, user.lastDailyCheckIn, user.lastWeeklyCheckIn);
    }

    function getPointsAccNextTime(address _user) external view returns (uint256 nextHourlyCheckIn, uint256 nextDailyCheckIn, uint256 nextWeeklyCheckIn) {
        User storage user = users[_user];
        return (
            user.lastHourlyCheckIn + HOUR,
            user.lastDailyCheckIn + DAY,
            user.lastWeeklyCheckIn + WEEK
        );
    }

    function getCurrentRewards() external view returns (uint256 hourly, uint256 daily, uint256 weekly) {
        return (hourlyReward, dailyReward, weeklyReward);
    }

    function getTotalUsers() external view returns (uint256) {
        return participants.length();
    }

    function getTotalPoints() external view returns (uint256 totalPoints) {
        uint256 length = participants.length();
        for (uint256 i = 0; i < length; i++) {
            totalPoints += users[participants.at(i)].points;
        }
    }

    function getTotalParticipants() external view returns (address[] memory) {
        uint256 length = participants.length();
        address[] memory allParticipants = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allParticipants[i] = participants.at(i);
        }
        return allParticipants;
    }

    function getSortedParticipants() external view returns (address[] memory, uint256[] memory) {
        uint256 length = participants.length();
        address[] memory sortedAddresses = new address[](length);
        uint256[] memory sortedPoints = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            sortedAddresses[i] = participants.at(i);
            sortedPoints[i] = users[sortedAddresses[i]].points;
        }
        
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (sortedPoints[i] < sortedPoints[j]) {
                    (sortedPoints[i], sortedPoints[j]) = (sortedPoints[j], sortedPoints[i]);
                    (sortedAddresses[i], sortedAddresses[j]) = (sortedAddresses[j], sortedAddresses[i]);
                }
            }
        }
        
        return (sortedAddresses, sortedPoints);
    }

    function getSSData(uint256 _ss) external view returns (uint256 totalUsers, uint256 totalPoints, address[] memory totalAddress) {
        Data storage data = ssData[_ss];
        return (data.totalUsers, data.totalPoints, data.users); 
    }

    function getPointsForSS(address _user, uint256 _ss) external view returns (uint256) {
        return ssData[_ss].userPoints[_user];
    }

    function getPointsAll(address _user) external view returns (uint256 totalPoints) {
        for (uint256 i = 1; i <= SS; i++) {
            totalPoints += ssData[i].userPoints[_user];
        }
    }

    function getLastReductionTime() external view returns (uint256) {
        return lastReductionTime;
    }

    function getNextReductionTime() external view returns (uint256) {
        return nextReductionTime;
    }

    function getHourlyReward() external view returns (uint256) {
        return hourlyReward;
    }

    function getDailyReward() external view returns (uint256) {
        return dailyReward;
    }

    function getWeeklyReward() external view returns (uint256) {
        return weeklyReward;
    }

    function getHourlyRewardCount() external view returns (uint256) {
        return hourlyRewardCount;
    }

    function getDailyRewardCount() external view returns (uint256) {
        return dailyRewardCount;
    }

    function getWeeklyRewardCount() external view returns (uint256) {
        return weeklyRewardCount;
    }

    function getRewardCountTypeForSS(uint256 _ss, uint256 _value) external view returns (uint256) {
        return ssData[_ss].countPointsSS[_value];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setHourlyReward(uint256 _hourly) external onlyOwner {
        hourlyReward = _hourly;
    }

    function setDailyReward(uint256 _daily) external onlyOwner {
        dailyReward = _daily;
    }

    function setWeeklyReward(uint256 _weekly) external onlyOwner {
        weeklyReward = _weekly;
    }

    function setReductionCycle(uint256 _interval) external onlyOwner {
        reductionCycle = _interval;
        nextReductionTime = lastReductionTime + _interval;
    }

    function resetPointsToNewSS() external onlyOwner {
        uint256 length = participants.length();
        uint256 totalUsers = length;
        uint256 totalPoints = 0;
        address[] memory allUsers = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            address user = participants.at(i);
            allUsers[i] = user;
            totalPoints += users[user].points;
            users[user].points = 0;
            emit PointsReset(user);
        }

        while (participants.length() > 0) {
            participants.remove(participants.at(0));
        }

        ssData[SS].totalUsers = totalUsers;
        ssData[SS].totalPoints = totalPoints;
        ssData[SS].users = allUsers;
        
        hourlyRewardCountSS = 0;
        dailyRewardCountSS = 0;
        weeklyRewardCountSS = 0;

        SS++;
    }
}
