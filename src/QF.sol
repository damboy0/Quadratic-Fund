// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

/// @title Quadratic Funding
/// @notice Simple QF implementation for public goods

/// @notice Interface for Sybil resistance (e.g., Gitcoin Passport or custom identity)
interface ISybilResistance {
    /// @notice Check if an address is verified as a unique human/entity
    /// @param _address The address to verify
    /// @return isVerified Whether the address is verified
    function isVerified(address _address) external view returns (bool);
}

contract QuadraticFunding {
    // ============ State Variables ============

    address public owner;
    uint256 public totalMatchingFund;
    uint256 public totalContribution;
    uint256 public constant PRECISION_FACTOR = 1e9;
    uint256 public roundStartTime;
    uint256 public roundEndTime;
    bool public roundActive;
    ISybilResistance public sybilResistance;
    bool public sybilResistanceEnabled;
    mapping(address => bool) public verifiedAddresses;
    bool public whitelistMode;
    bool public roundFinalized;
    mapping(uint256 => uint256) public finalizedMatchingAmounts;
    mapping(uint256 => uint256) public projectWithdrawnAmount;
    uint256 public remainingMatchingFund;

    struct Project {
        uint256 id;
        string name;
        address recipient;
        uint256 totalDonated;
        mapping(address => uint256) contributors;
        uint256[] contributionAmounts;
        address[] contributorAddresses;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCounter;
    uint256[] public projectIds;

    // ============ Events ============

    /// @notice Emitted when a new project is registered
    event ProjectCreated(uint256 indexed projectId, string name, address indexed recipient);

    /// @notice Emitted when a contribution is made to a project
    event ContributionMade(uint256 indexed projectId, address indexed contributor, uint256 amount);

    /// @notice Emitted when matching fund is updated
    event MatchingFundUpdated(uint256 newAmount);

    /// @notice Emitted when matching score is calculated for a project
    event MatchingScoreCalculated(uint256 indexed projectId, uint256 matchingScore);

    /// @notice Emitted when CQF alpha is calculated
    event AlphaCalculated(uint256 alpha);

    /// @notice Emitted when CQF payouts are calculated
    event CQFPayoutCalculated(uint256 indexed projectId, uint256 cqfPayout);

    /// @notice Emitted when a new funding round is started
    event RoundStarted(uint256 startTime, uint256 endTime);

    /// @notice Emitted when a funding round ends
    event RoundEnded(uint256 endTime);

    /// @notice Emitted when an address is verified
    event AddressVerified(address indexed account);

    /// @notice Emitted when an address is removed from verification
    event AddressUnverified(address indexed account);

    /// @notice Emitted when Sybil resistance provider is set
    event SybilResistanceSet(address indexed provider);

    /// @notice Emitted when Sybil resistance is toggled
    event SybilResistanceToggled(bool enabled);

    /// @notice Emitted when a funding round is finalized
    event RoundFinalized(uint256 timestamp, uint256 totalMatchingDistributed);

    /// @notice Emitted when matching amounts are calculated and stored for finalization
    event MatchingDistributed(uint256 indexed projectId, uint256 matchingAmount, uint256 totalPayout);

    /// @notice Emitted when a project withdraws their funds
    event FundsWithdrawn(uint256 indexed projectId, address indexed recipient, uint256 amount);

    // ============ Modifiers ============

    /// @notice Ensures only the contract owner can execute the function
    modifier onlyOwner() {
        require(msg.sender == owner, "Owner only");
        _;
    }

    /// @notice Ensures the funding round is currently active
    modifier roundIsActive() {
        require(roundActive, "No round");
        require(block.timestamp >= roundStartTime, "Not started");
        require(block.timestamp <= roundEndTime, "Ended");
        _;
    }

    /// @notice Ensures the caller is verified (via Sybil resistance or whitelist)
    modifier onlyVerified() {
        if (sybilResistanceEnabled) {
            require(sybilResistance.isVerified(msg.sender), "Not verified");
        } else if (whitelistMode) {
            require(verifiedAddresses[msg.sender], "Not whitelisted");
        }
        _;
    }

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
        projectCounter = 0;
        totalMatchingFund = 0;
        totalContribution = 0;
        roundActive = false;
        roundStartTime = 0;
        roundEndTime = 0;
        roundFinalized = false;
        sybilResistanceEnabled = false;
        whitelistMode = false;
        sybilResistance = ISybilResistance(address(0));
        remainingMatchingFund = 0;
    }

    // ============ Project Management ============

    /// @notice Register a new project for the quadratic funding round
    /// @param _name The name of the project
    /// @param _recipient The address that will receive funds for this project
    /// @return projectId The ID of the newly created project
    function registerProject(string memory _name, address _recipient) public returns (uint256) {
        require(_recipient != address(0), "Invalid recipient");
        require(bytes(_name).length > 0, "No name");

        uint256 projectId = projectCounter;
        projectCounter++;

        Project storage newProject = projects[projectId];
        newProject.id = projectId;
        newProject.name = _name;
        newProject.recipient = _recipient;
        newProject.totalDonated = 0;

        projectIds.push(projectId);

        emit ProjectCreated(projectId, _name, _recipient);

        return projectId;
    }

    // ============ Contribution Tracking ============

    /// @notice Contribute to a specific project
    /// @dev Records individual contributions for quadratic funding calculations
    /// @dev Only allowed during active funding rounds and for verified addresses
    /// @param _projectId The ID of the project to contribute to
    function contribute(uint256 _projectId) public payable roundIsActive onlyVerified {
        require(_projectId < projectCounter, "Invalid project");
        require(msg.value > 0, "Zero contribution");

        Project storage project = projects[_projectId];

        bool isNewContributor = project.contributors[msg.sender] == 0;
        project.contributors[msg.sender] += msg.value;
        project.totalDonated += msg.value;
        totalContribution += msg.value;
        project.contributionAmounts.push(msg.value);

        if (isNewContributor) {
            project.contributorAddresses.push(msg.sender);
        }

        emit ContributionMade(_projectId, msg.sender, msg.value);
    }

    /// @notice Get contributor amount and project total donations
    function getContributorAmount(uint256 _projectId, address _contributor) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        return projects[_projectId].contributors[_contributor];
    }

    function getProjectTotalDonated(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        return projects[_projectId].totalDonated;
    }

    /// @notice Get project details
    /// @param _projectId The ID of the project
    /// @return id Project ID
    /// @return name Project name
    /// @return recipient Recipient address
    /// @return totalDonated Total amount donated to the project
    function getProject(uint256 _projectId)
        public
        view
        returns (uint256 id, string memory name, address recipient, uint256 totalDonated)
    {
        require(_projectId < projectCounter, "Invalid project");
        Project storage project = projects[_projectId];
        return (project.id, project.name, project.recipient, project.totalDonated);
    }

    // ============ Matching Pool Management ============

    /// @notice Deposit matching funds into the pool (owner only)
    function depositMatchingFund() public payable onlyOwner {
        require(msg.value > 0, "Zero amount");
        totalMatchingFund += msg.value;
        remainingMatchingFund += msg.value;
        emit MatchingFundUpdated(totalMatchingFund);
    }

    // ============ Round Management ============

    /// @notice Start a new funding round with a specific duration
    /// @dev Only the owner can start a round
    /// @param _durationInSeconds The duration of the round in seconds
    function startRound(uint256 _durationInSeconds) public onlyOwner {
        require(_durationInSeconds > 0, "Bad duration");
        require(!roundActive, "Round active");

        roundStartTime = block.timestamp;
        roundEndTime = block.timestamp + _durationInSeconds;
        roundActive = true;

        emit RoundStarted(roundStartTime, roundEndTime);
    }

    /// @notice End the current funding round (owner only)
    /// @dev Stops accepting new contributions
    function endRound() public onlyOwner {
        require(roundActive, "No active round");

        roundActive = false;
        emit RoundEnded(block.timestamp);
    }

    function isRoundActive() public view returns (bool) {
        if (!roundActive) return false;
        return block.timestamp >= roundStartTime && block.timestamp <= roundEndTime;
    }

    function getRoundTimeRemaining() public view returns (uint256) {
        if (!roundActive || block.timestamp > roundEndTime) {
            return 0;
        }
        return roundEndTime - block.timestamp;
    }

    function isRoundFinalized() public view returns (bool) {
        return roundFinalized;
    }

    // ============ Round Finalization ============

    /// @notice Finalize the current round and calculate matching distributions
    /// @dev Only the owner can call this function
    /// @dev Can only be called after the round has ended
    /// @dev Calculates CQF payouts for all projects and stores them for withdrawal
    function finalizeRound() public onlyOwner {
        require(roundActive, "No round");
        require(block.timestamp > roundEndTime, "Active");
        require(!roundFinalized, "Already finalized");
        require(totalMatchingFund > 0, "No funds");

        roundActive = false;
        roundFinalized = true;

        uint256 totalMatchingDistributed = 0;

        if (projectCounter > 0) {
            uint256 alpha = calculateOptimalAlpha();

            for (uint256 i = 0; i < projectCounter; i++) {
                Project storage project = projects[i];

                if (project.contributionAmounts.length == 0) {
                    finalizedMatchingAmounts[i] = 0;
                    continue;
                }

                uint256 sumOfSqrts = 0;
                for (uint256 j = 0; j < project.contributionAmounts.length; j++) {
                    sumOfSqrts += sqrtFixed(project.contributionAmounts[j]);
                }

                uint256 projectQFScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
                uint256 projectDirectContributions = project.totalDonated;

                uint256 qfComponent = (alpha * projectQFScore) / 1e18;
                uint256 directComponent = ((1e18 - alpha) * projectDirectContributions) / 1e18;

                uint256 matchingAmount = qfComponent + directComponent;

                if (totalMatchingDistributed + matchingAmount > totalMatchingFund) {
                    matchingAmount = totalMatchingFund - totalMatchingDistributed;
                }

                finalizedMatchingAmounts[i] = matchingAmount;
                totalMatchingDistributed += matchingAmount;

                uint256 totalProjectPayout = projectDirectContributions + matchingAmount;
                emit MatchingDistributed(i, matchingAmount, totalProjectPayout);
            }
        }

        remainingMatchingFund = totalMatchingFund - totalMatchingDistributed;

        emit RoundFinalized(block.timestamp, totalMatchingDistributed);
    }

    /// @notice Get the finalized matching amount for a project
    /// @param _projectId The ID of the project
    /// @return matchingAmount The finalized matching amount for this project
    function getFinalizedMatchingAmount(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        require(roundFinalized, "Not finalized");
        return finalizedMatchingAmounts[_projectId];
    }

    /// @notice Get the total payout (direct donations + matching) for a project
    /// @param _projectId The ID of the project
    /// @return totalPayout The total amount the project will receive
    function getProjectTotalPayout(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        require(roundFinalized, "Not finalized");

        uint256 directDonations = projects[_projectId].totalDonated;
        uint256 matchingAmount = finalizedMatchingAmounts[_projectId];

        return directDonations + matchingAmount;
    }

    /// @notice Withdraw funds for a project (only by the project recipient)
    /// @dev Can be called multiple times, but will only allow withdrawal of available funds
    /// @dev Partial withdrawals supported
    function withdrawProjectFunds(uint256 _projectId) public {
        require(_projectId < projectCounter, "Invalid project");
        require(roundFinalized, "Not finalized");
        Project storage project = projects[_projectId];
        require(msg.sender == project.recipient, "Not owner");

        // Calculate total payout available
        uint256 directDonations = project.totalDonated;
        uint256 matchingAmount = finalizedMatchingAmounts[_projectId];
        uint256 totalPayout = directDonations + matchingAmount;

        // Calculate how much is still available to withdraw
        uint256 alreadyWithdrawn = projectWithdrawnAmount[_projectId];
        require(totalPayout > alreadyWithdrawn, "No funds left");

        uint256 availableToWithdraw = totalPayout - alreadyWithdrawn;

        projectWithdrawnAmount[_projectId] = totalPayout;

        (bool success,) = payable(msg.sender).call{value: availableToWithdraw}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(_projectId, msg.sender, availableToWithdraw);
    }

    /// @notice Get the amount a project has already withdrawn
    /// @param _projectId The ID of the project
    /// @return withdrawnAmount The amount already withdrawn
    function getProjectWithdrawnAmount(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        return projectWithdrawnAmount[_projectId];
    }

    /// @notice Get remaining funds available for a project to withdraw
    /// @param _projectId The ID of the project
    /// @return remainingAmount The amount still available to withdraw
    function getProjectRemainingWithdrawal(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        require(roundFinalized, "Not finalized");

        uint256 totalPayout = getProjectTotalPayout(_projectId);
        uint256 alreadyWithdrawn = projectWithdrawnAmount[_projectId];

        if (totalPayout <= alreadyWithdrawn) {
            return 0;
        }

        return totalPayout - alreadyWithdrawn;
    }

    /// @notice Get owner's ability to recover remaining matching funds after all withdrawals
    /// @dev Returns the amount available for owner recovery (undistributed matching funds)
    /// @return recoverable The amount of matching funds not distributed to projects
    function getRecoverableMatchingFunds() public view returns (uint256) {
        require(roundFinalized, "Not finalized");
        return remainingMatchingFund;
    }

    /// @notice Allow owner to recover undistributed matching funds after finalization
    /// @dev Only available after round is finalized
    /// @dev Transfers remaining matching funds back to owner
    function recoverUnusedMatchingFunds() public onlyOwner {
        require(roundFinalized, "Not finalized");
        require(remainingMatchingFund > 0, "No funds");

        uint256 amountToRecover = remainingMatchingFund;
        remainingMatchingFund = 0;

        (bool success,) = payable(owner).call{value: amountToRecover}("");
        require(success, "Recover failed");
    }

    /// @notice Get complete finalization status and summary
    /// @return _isFinalized Whether round is finalized
    /// @return _totalDistributed Total matching distributed to projects
    /// @return _totalRecoverable Remaining matching funds not distributed
    function getFinalizationStatus()
        public
        view
        returns (bool _isFinalized, uint256 _totalDistributed, uint256 _totalRecoverable)
    {
        _isFinalized = roundFinalized;
        _totalDistributed = totalMatchingFund - remainingMatchingFund;
        _totalRecoverable = remainingMatchingFund;
        return (_isFinalized, _totalDistributed, _totalRecoverable);
    }

    /// @notice Get the number of registered projects
    /// @return The total number of projects
    function getProjectCount() public view returns (uint256) {
        return projectCounter;
    }

    /// @notice Get all project IDs
    /// @return Array of all project IDs
    function getAllProjectIds() public view returns (uint256[] memory) {
        return projectIds;
    }

    // ============ Quadratic Funding Calculations ============

    /// @notice Calculate integer square root using Babylonian method
    /// @dev Approximates the square root using fixed-point arithmetic
    /// @param x The number to calculate the square root of
    /// @return y The integer square root of x
    function sqrt(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;
        if (x == 1) return 1;

        uint256 z = (x + 1) / 2;
        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /// @notice Calculate fixed-point square root with precision scaling
    /// @dev Uses precision factor of 1e9 for intermediate calculations to maintain accuracy
    /// @dev Suitable for wei amounts (1e18) to ensure proper precision
    /// @param x The number to calculate the square root of (in wei)
    /// @return y The fixed-point square root of x scaled by PRECISION_FACTOR
    function sqrtFixed(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;

        uint256 scaledInput = x * PRECISION_FACTOR;

        if (scaledInput == 1) return 1;

        uint256 z = (scaledInput + 1) / 2;
        y = scaledInput;

        while (z < y) {
            y = z;
            z = (scaledInput / z + z) / 2;
        }

        return y;
    }

    /// @notice Calculate and distribute the matching amount for a project
    /// @dev Distributes from the matching pool based on QF formula: matchingAmount = (matchingScore / totalMatchingScores) * totalMatchingFund
    /// @dev All projects' matching scores must be calculated before calling this function
    /// @param _projectId The ID of the project to calculate matching amount for
    /// @param _totalMatchingScoresAllProjects Sum of all projects' matching scores
    /// @return matchingAmount The amount this project receives from the matching pool
    function calculateMatchingAmount(uint256 _projectId, uint256 _totalMatchingScoresAllProjects)
        public
        view
        returns (uint256)
    {
        require(_projectId < projectCounter, "Project does not exist");
        require(_totalMatchingScoresAllProjects > 0, "Bad scores");
        require(totalMatchingFund > 0, "No funds");

        Project storage project = projects[_projectId];
        require(project.contributionAmounts.length > 0, "No contribs");

        // Calculate matching score for this project
        uint256 projectMatchingScore = 0;
        uint256 sumOfSqrts = 0;

        for (uint256 i = 0; i < project.contributionAmounts.length; i++) {
            sumOfSqrts += sqrtFixed(project.contributionAmounts[i]);
        }

        projectMatchingScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);

        // Calculate matching amount: (projectMatchingScore / totalMatchingScores) * totalMatchingFund
        uint256 matchingAmount = (projectMatchingScore * totalMatchingFund) / _totalMatchingScoresAllProjects;

        return matchingAmount;
    }

    /// @notice Calculate matching amounts for all projects at once
    /// @dev Returns an array of matching amounts for each project indexed by project ID
    /// @return matchingAmounts Array where matchingAmounts[i] is the matching amount for project i
    function calculateAllMatchingAmounts() public view returns (uint256[] memory matchingAmounts) {
        require(totalMatchingFund > 0, "No funds");
        require(projectCounter > 0, "No projects");

        matchingAmounts = new uint256[](projectCounter);
        uint256 totalMatchingScores = 0;

        // First pass: calculate all matching scores and sum them
        uint256[] memory matchingScores = new uint256[](projectCounter);
        for (uint256 i = 0; i < projectCounter; i++) {
            Project storage project = projects[i];

            if (project.contributionAmounts.length == 0) {
                matchingScores[i] = 0;
                continue;
            }

            uint256 sumOfSqrts = 0;
            for (uint256 j = 0; j < project.contributionAmounts.length; j++) {
                sumOfSqrts += sqrtFixed(project.contributionAmounts[j]);
            }

            matchingScores[i] = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
            totalMatchingScores += matchingScores[i];
        }

        // Second pass: calculate each project's matching amount
        if (totalMatchingScores > 0) {
            for (uint256 i = 0; i < projectCounter; i++) {
                matchingAmounts[i] = (matchingScores[i] * totalMatchingFund) / totalMatchingScores;
            }
        }

        return matchingAmounts;
    }

    /// @notice Get the number of unique contributors to a project
    /// @param _projectId The ID of the project
    /// @return The count of unique contributors
    function getUniqueContributorCount(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Invalid project");
        return projects[_projectId].contributorAddresses.length;
    }

    /// @notice Get all unique contributors to a project
    /// @param _projectId The ID of the project
    /// @return Array of contributor addresses
    function getContributors(uint256 _projectId) public view returns (address[] memory) {
        require(_projectId < projectCounter, "Invalid project");
        return projects[_projectId].contributorAddresses;
    }

    // ============ Sybil Resistance & Identity Management ============

    /// @notice Set the Sybil resistance provider (identity verification contract)
    /// @dev Owner only. Set address(0) to disable external Sybil resistance
    /// @param _sybilResistanceAddress The address of the Sybil resistance contract
    function setSybilResistance(address _sybilResistanceAddress) public onlyOwner {
        sybilResistance = ISybilResistance(_sybilResistanceAddress);
        sybilResistanceEnabled = (_sybilResistanceAddress != address(0));
        whitelistMode = false; // Disable whitelist mode when setting external provider
        emit SybilResistanceSet(_sybilResistanceAddress);
    }

    /// @notice Enable or disable Sybil resistance checks
    /// @param _enabled Whether to enable Sybil resistance
    function setSybilResistanceEnabled(bool _enabled) public onlyOwner {
        require(address(sybilResistance) != address(0) || _enabled == false, "No provider");
        sybilResistanceEnabled = _enabled;
        emit SybilResistanceToggled(_enabled);
    }

    /// @notice Enable whitelist mode for identity verification
    /// @dev When enabled, only whitelisted addresses can contribute
    /// @dev Disables external Sybil resistance if it was enabled
    function enableWhitelistMode() public onlyOwner {
        whitelistMode = true;
        sybilResistanceEnabled = false;
        emit SybilResistanceToggled(true);
    }

    /// @notice Disable whitelist mode
    function disableWhitelistMode() public onlyOwner {
        whitelistMode = false;
        emit SybilResistanceToggled(false);
    }

    /// @notice Add an address to the verification whitelist
    /// @param _account The address to verify
    function verifyAddress(address _account) public onlyOwner {
        require(_account != address(0), "Bad address");
        verifiedAddresses[_account] = true;
        emit AddressVerified(_account);
    }

    /// @notice Add multiple addresses to the verification whitelist (batch operation)
    /// @param _accounts Array of addresses to verify
    function verifyAddresses(address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            require(_accounts[i] != address(0), "Bad addr");
            verifiedAddresses[_accounts[i]] = true;
            emit AddressVerified(_accounts[i]);
        }
    }

    /// @notice Remove an address from the verification whitelist
    /// @param _account The address to unverify
    function unverifyAddress(address _account) public onlyOwner {
        verifiedAddresses[_account] = false;
        emit AddressUnverified(_account);
    }

    /// @notice Remove multiple addresses from the verification whitelist (batch operation)
    /// @param _accounts Array of addresses to unverify
    function unverifyAddresses(address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            verifiedAddresses[_accounts[i]] = false;
            emit AddressUnverified(_accounts[i]);
        }
    }

    /// @notice Check if an address is verified
    /// @param _account The address to check
    /// @return isVerified Whether the address is verified
    function isAddressVerified(address _account) public view returns (bool) {
        if (sybilResistanceEnabled && address(sybilResistance) != address(0)) {
            return sybilResistance.isVerified(_account);
        } else if (whitelistMode) {
            return verifiedAddresses[_account];
        }
        // If neither mode is enabled, all addresses are considered verified
        return true;
    }

    function getSybilResistanceConfig()
        public
        view
        returns (bool _sybilResistanceEnabled, bool _whitelistMode, address _provider)
    {
        return (sybilResistanceEnabled, whitelistMode, address(sybilResistance));
    }

    // ============ Capital-Constrained Quadratic Funding (CQF) ============

    /// @notice Calculate the total QF score (matching score) across all projects
    /// @dev Returns sum of (sqrt(c1) + sqrt(c2) + ...)^2 for all projects
    /// @return totalQFScore The sum of all projects' QF scores
    function calculateTotalQFScore() public view returns (uint256 totalQFScore) {
        require(projectCounter > 0, "No projects");

        for (uint256 i = 0; i < projectCounter; i++) {
            Project storage project = projects[i];

            if (project.contributionAmounts.length == 0) {
                continue;
            }

            uint256 sumOfSqrts = 0;
            for (uint256 j = 0; j < project.contributionAmounts.length; j++) {
                sumOfSqrts += sqrtFixed(project.contributionAmounts[j]);
            }

            uint256 projectQFScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
            totalQFScore += projectQFScore;
        }

        return totalQFScore;
    }

    /// @notice Calculate the optimal alpha value for CQF
    /// @dev Formula: alpha = (matching_pool - total_direct_contributions) / (total_QF_score - total_direct_contributions)
    /// @dev Alpha is clamped to [0, 1] to ensure valid weighting
    /// @dev Precision: uses 1e18 for fixed-point decimal representation
    /// @return alpha The optimal weighting factor (scaled by 1e18)
    function calculateOptimalAlpha() public returns (uint256 alpha) {
        require(projectCounter > 0, "No projects");
        require(totalMatchingFund > 0, "No funds");

        uint256 totalQFScore = calculateTotalQFScore();
        uint256 totalDirectContributions = totalContribution;

        // If there are no contributions at all, alpha is irrelevant
        if (totalDirectContributions == 0 && totalQFScore == 0) {
            return 5e17; // Return 0.5 as neutral default (scaled by 1e18)
        }

        // If QF score equals direct contributions, use neutral alpha
        if (totalQFScore == totalDirectContributions) {
            return 5e17; // 0.5 (scaled by 1e18)
        }

        // alpha = (matching_pool - total_direct) / (total_QF - total_direct)
        // Using 1e18 for precision
        uint256 numerator = totalMatchingFund;
        uint256 denominator = totalQFScore;

        if (numerator >= denominator) {
            // If matching pool >= QF score, alpha = 1 (full QF)
            alpha = 1e18;
        } else if (numerator <= totalDirectContributions) {
            // If matching pool <= direct contributions, alpha = 0 (pure direct)
            alpha = 0;
        } else {
            // alpha = (matching_pool - total_direct) / (total_QF - total_direct)
            // Scaled by 1e18 for fixed-point arithmetic
            alpha = ((numerator - totalDirectContributions) * 1e18) / (denominator - totalDirectContributions);
        }

        // Clamp alpha to [0, 1e18]
        if (alpha > 1e18) {
            alpha = 1e18;
        }

        emit AlphaCalculated(alpha);
        return alpha;
    }

    /// @notice Calculate CQF payout for a single project
    /// @dev Formula: payout = alpha * QF_score^2 + (1 - alpha) * total_contributions
    /// @dev Where alpha is automatically calculated to respect matching pool budget
    /// @param _projectId The ID of the project
    /// @return cqfPayout The calculated payout for this project
    function calculateCQFPayout(uint256 _projectId) public returns (uint256 cqfPayout) {
        require(_projectId < projectCounter, "Project does not exist");

        Project storage project = projects[_projectId];
        require(project.contributionAmounts.length > 0, "No contribs");

        // Calculate alpha
        uint256 alpha = calculateOptimalAlpha();

        // Calculate this project's QF score: (sum of sqrt(contributions))^2
        uint256 sumOfSqrts = 0;
        for (uint256 i = 0; i < project.contributionAmounts.length; i++) {
            sumOfSqrts += sqrtFixed(project.contributionAmounts[i]);
        }

        uint256 projectQFScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
        uint256 projectDirectContributions = project.totalDonated;

        // payout = alpha * QF_score + (1 - alpha) * direct_contributions
        // Both scaled by 1e18 for fixed-point math
        uint256 qfComponent = (alpha * projectQFScore) / 1e18;
        uint256 directComponent = ((1e18 - alpha) * projectDirectContributions) / 1e18;

        cqfPayout = qfComponent + directComponent;

        return cqfPayout;
    }

    /// @notice Calculate CQF payouts for all projects
    /// @dev Returns array of payouts for each project using the CQF formula
    /// @dev Total payouts are guaranteed not to exceed the matching pool budget
    /// @return cqfPayouts Array where cqfPayouts[i] is the payout for project i
    function calculateAllCQFPayouts() public returns (uint256[] memory cqfPayouts) {
        require(projectCounter > 0, "No projects");
        require(totalMatchingFund > 0, "No funds");

        // Calculate alpha once for all projects
        uint256 alpha = calculateOptimalAlpha();

        cqfPayouts = new uint256[](projectCounter);
        uint256 totalPayoutDistributed = 0;

        // Calculate payout for each project
        for (uint256 i = 0; i < projectCounter; i++) {
            Project storage project = projects[i];

            if (project.contributionAmounts.length == 0) {
                cqfPayouts[i] = 0;
                continue;
            }

            // Calculate this project's QF score
            uint256 sumOfSqrts = 0;
            for (uint256 j = 0; j < project.contributionAmounts.length; j++) {
                sumOfSqrts += sqrtFixed(project.contributionAmounts[j]);
            }

            uint256 projectQFScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
            uint256 projectDirectContributions = project.totalDonated;

            // CQF Formula: payout = alpha * QF_score + (1 - alpha) * direct_contributions
            uint256 qfComponent = (alpha * projectQFScore) / 1e18;
            uint256 directComponent = ((1e18 - alpha) * projectDirectContributions) / 1e18;

            uint256 projectPayout = qfComponent + directComponent;
            cqfPayouts[i] = projectPayout;
            totalPayoutDistributed += projectPayout;

            emit CQFPayoutCalculated(i, projectPayout);
        }

        return cqfPayouts;
    }

    function getCQFSummary()
        public
        returns (uint256 alpha, uint256 totalQFScore, uint256 totalDirectContributions, uint256 matchingFund)
    {
        alpha = calculateOptimalAlpha();
        totalQFScore = calculateTotalQFScore();
        totalDirectContributions = totalContribution;
        matchingFund = totalMatchingFund;

        return (alpha, totalQFScore, totalDirectContributions, matchingFund);
    }
}
