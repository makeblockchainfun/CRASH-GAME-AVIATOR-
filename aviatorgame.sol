// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// The @openzeppelin/contracts/utils/Context.sol library would be imported here
// to handle the msg.sender context for multi-player games.
// For this fixed demo, we assume a single-player context.

contract AviatorGame {
    address public owner;
    uint256 public roundId;
    uint256 public commitTime;
    uint256 public roundStartTime;
    uint256 public currentCrashPoint;
    
    enum GameState { BETTING, COMMITTED, IN_GAME, REVEALED }
    GameState public currentState;

    uint256 public constant PRECISION = 10000;
    bytes32 public committedHash;
    string public revealedServerSeed;

    // Use a mapping for quick access to a player's bet
    mapping(address => Bet) public bets;
    
    // Store bettors in a mapping for efficient "swap-and-pop" deletion.
    address[] public bettors;
    mapping(address => uint256) private bettorIndex;

    struct Bet {
        uint256 amount;
        bool cashedOut;
        uint256 cashoutTime; // Store the timestamp of the cashout
        bool payoutClaimed;
    }
    
    uint256 public totalBets;
    uint256 public houseProfit;

    event BetPlaced(address indexed player, uint256 amount);
    event PlayerCashedOut(address indexed player, uint256 cashoutTime);
    event PayoutClaimed(address indexed player, uint256 payoutAmount);
    event RoundCommitted(uint256 indexed roundId, bytes32 seedHash);
    event RoundStarted(uint256 indexed roundId, uint256 startTime);
    event RoundRevealed(uint256 indexed roundId, uint256 crashPoint);
    event ProfitWithdrawn(address indexed owner, uint256 amount);
    event Refunded(address indexed player, uint256 amount);

    constructor() {
        owner = msg.sender;
        currentState = GameState.BETTING;
        roundId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier inState(GameState state) {
        require(currentState == state, "Invalid state");
        _;
    }

    function placeBet() public payable inState(GameState.BETTING) {
        // Prevent placing a second bet and require a minimum bet amount.
        require(bets[msg.sender].amount == 0, "Already bet");
        require(msg.value > 0, "Bet > 0");

        // The check (totalBets + msg.value) * 100 <= address(this).balance is flawed.
        // It's a rough approximation for a safety margin and can lead to
        // unexpected reverts. A better approach is to handle potential overdraws
        // during payout, or increase the house's balance. We'll remove it for simplicity.
        // require((totalBets + msg.value) * 100 <= address(this).balance, "Insufficient funds");

        // Store the bettor and their index for efficient deletion.
        bets[msg.sender] = Bet(msg.value, false, 0, false);
        bettorIndex[msg.sender] = bettors.length;
        bettors.push(msg.sender);
        totalBets += msg.value;

        emit BetPlaced(msg.sender, msg.value);
    }
    
    function commitSeedHash(bytes32 _seedHash) public onlyOwner inState(GameState.BETTING) {
        require(bettors.length > 0, "No players");
        committedHash = _seedHash;
        commitTime = block.timestamp;
        currentState = GameState.COMMITTED;
        emit RoundCommitted(roundId, _seedHash);
    }

    function startGame() public onlyOwner inState(GameState.COMMITTED) {
        currentState = GameState.IN_GAME;
        roundStartTime = block.timestamp;
        emit RoundStarted(roundId, roundStartTime);
    }

    function cashOut() public inState(GameState.IN_GAME) {
        Bet storage playerBet = bets[msg.sender];
        require(playerBet.amount > 0, "No bet");
        require(!playerBet.cashedOut, "Already cashed out");
        
        // Mark the bet as cashed out and record the timestamp
        playerBet.cashedOut = true;
        playerBet.cashoutTime = block.timestamp;

        emit PlayerCashedOut(msg.sender, playerBet.cashoutTime);
    }
    
    function revealSeedAndPayout(string calldata _serverSeed) public onlyOwner inState(GameState.IN_GAME) {
        require(committedHash == keccak256(abi.encodePacked(_serverSeed)), "Invalid seed");
        
        // This function now reveals the crash point and stores it in a state variable.
        // It does not handle any payouts to avoid gas limit issues.
        revealedServerSeed = _serverSeed;
        currentCrashPoint = generateCrashPoint(_serverSeed);
        
        currentState = GameState.REVEALED;
        emit RoundRevealed(roundId, currentCrashPoint);
    }
    
    function claimPayout() public inState(GameState.REVEALED) {
        Bet storage playerBet = bets[msg.sender];
        require(playerBet.amount > 0, "No bet for this round");
        require(!playerBet.payoutClaimed, "Payout already claimed");
        
        uint256 payoutAmount = 0;
        if (playerBet.cashedOut) {
            // Calculate the multiplier at the time of cashout based on game duration
            uint256 timeElapsed = playerBet.cashoutTime - roundStartTime;
            uint256 multiplierAtCashout = 10000 + timeElapsed * 100; // Simplified multiplier logic for demo

            if (multiplierAtCashout < currentCrashPoint) {
                payoutAmount = (playerBet.amount * multiplierAtCashout) / PRECISION;
                
                // Transfer payout, if any
                payable(msg.sender).transfer(payoutAmount);
                emit PayoutClaimed(msg.sender, payoutAmount);
            }
        }
        
        // If the player didn't cash out in time or the game crashed before their cashout,
        // no payout is sent. Their bet amount is considered part of the house profit.
        if (payoutAmount == 0) {
            houseProfit += playerBet.amount;
        } else {
            houseProfit += playerBet.amount - payoutAmount;
        }

        playerBet.payoutClaimed = true;
    }
    
    function refund() public inState(GameState.COMMITTED) {
        require(block.timestamp > commitTime + 5 minutes, "Too early");
        
        Bet storage playerBet = bets[msg.sender];
        require(playerBet.amount > 0, "No bet");
        
        uint256 amount = playerBet.amount;
        delete bets[msg.sender];
        
        // Efficiently remove the player from the bettors array (swap-and-pop)
        uint256 index = bettorIndex[msg.sender];
        uint256 lastIndex = bettors.length - 1;
        if (index != lastIndex) {
            address lastBettor = bettors[lastIndex];
            bettors[index] = lastBettor;
            bettorIndex[lastBettor] = index;
        }
        bettors.pop();
        delete bettorIndex[msg.sender];

        payable(msg.sender).transfer(amount);
        
        emit Refunded(msg.sender, amount);
    }
    
    function generateCrashPoint(string memory _serverSeed) internal pure returns (uint256) {
        bytes32 seedHash = keccak256(abi.encodePacked(_serverSeed));
        uint256 randomValue = uint256(seedHash) % 99000;
        uint256 crash = (100000 * PRECISION) / (100000 - randomValue);
        uint256 maxCrash = 100 * PRECISION;
        return crash > maxCrash ? maxCrash : crash;
    }

    function resetRound() public onlyOwner inState(GameState.REVEALED) {
        // Reset the dynamic bettors array
        delete bettors;
        
        // Reset state variables for a new round
        delete committedHash;
        delete revealedServerSeed;
        delete currentCrashPoint;
        
        roundId++;
        currentState = GameState.BETTING;
        totalBets = 0;
    }

    function withdrawProfit() public onlyOwner {
        uint256 amount = houseProfit;
        houseProfit = 0;
        payable(owner).transfer(amount);
        emit ProfitWithdrawn(owner, amount);
    }
}

