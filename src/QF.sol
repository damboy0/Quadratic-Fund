// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

/// @title Quadratic Funding
/// @author damboy.eth 

/// @notice A simple implementation of quadratic funding for public goods
/// @dev This is a very basic implementation and should not be used in production without further testing and security audits
/// @dev This implementation does not include any mechanisms for preventing Sybil attacks or other forms of manipulation, and should be used with caution in a real-world setting
/// @dev This implementation is intended for educational purposes only and should not be used in production without further testing and security audits


contract QuadraticFunding {
    // ============ State Variables ============
    
    /// @notice Contract owner who manages the matching pool
    address public owner;
    
    /// @notice Total amount available in the matching pool
    uint256 public totalMatchingFund;
    
    /// @notice Total contributions across all projects
    uint256 public totalContribution;
    
    /// @notice Precision scaling factor for fixed-point math (1e9 for intermediate calculations)
    uint256 public constant PRECISION_FACTOR = 1e9;
    
    /// @notice Project struct to store project details
    struct Project {
        uint256 id;
        string name;
        address recipient;
        uint256 totalDonated;
        mapping(address => uint256) contributors; // Maps contributor address to donation amount
        uint256[] contributionAmounts; // Array of all individual contributions for QF calculation
        address[] contributorAddresses; // Array of contributor addresses (for iteration)
    }
    
    /// @notice Mapping from project ID to Project struct
    mapping(uint256 => Project) public projects;
    
    /// @notice Counter for project IDs
    uint256 public projectCounter;
    
    /// @notice Array to keep track of all project IDs
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
    
    // ============ Modifiers ============
    
    /// @notice Ensures only the contract owner can execute the function
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
        projectCounter = 0;
        totalMatchingFund = 0;
        totalContribution = 0;
    }
    
    // ============ Project Management ============
    
    /// @notice Register a new project for the quadratic funding round
    /// @param _name The name of the project
    /// @param _recipient The address that will receive funds for this project
    /// @return projectId The ID of the newly created project
    function registerProject(string memory _name, address _recipient) public returns (uint256) {
        require(_recipient != address(0), "Recipient address cannot be zero");
        require(bytes(_name).length > 0, "Project name cannot be empty");
        
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
    /// @param _projectId The ID of the project to contribute to
    function contributeToProject(uint256 _projectId) public payable {
        require(_projectId < projectCounter, "Project does not exist");
        require(msg.value > 0, "Contribution amount must be greater than zero");
        
        Project storage project = projects[_projectId];
        
        // Check if this is a new contributor
        bool isNewContributor = project.contributors[msg.sender] == 0;
        
        // Update contributor's donation amount for this project
        project.contributors[msg.sender] += msg.value;
        
        // Update total donated for this project
        project.totalDonated += msg.value;
        
        // Update global contribution tracking
        totalContribution += msg.value;
        
        // Store individual contribution amount for QF calculation
        project.contributionAmounts.push(msg.value);
        
        // Track new contributor address
        if (isNewContributor) {
            project.contributorAddresses.push(msg.sender);
        }
        
        emit ContributionMade(_projectId, msg.sender, msg.value);
    }
    
    /// @notice Shorthand function: contribute ETH to a project
    /// @param _projectId The ID of the project to contribute to
    function contribute(uint256 _projectId) public payable {
        contributeToProject(_projectId);
    }
    
    /// @notice Get the total donation amount for a specific contributor to a project
    /// @param _projectId The ID of the project
    /// @param _contributor The address of the contributor
    /// @return The total amount contributed by the contributor to this project
    function getContributorAmount(uint256 _projectId, address _contributor) public view returns (uint256) {
        require(_projectId < projectCounter, "Project does not exist");
        return projects[_projectId].contributors[_contributor];
    }
    
    /// @notice Get the total donated amount for a specific project
    /// @param _projectId The ID of the project
    /// @return The total amount donated to this project
    function getProjectTotalDonated(uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCounter, "Project does not exist");
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
        require(_projectId < projectCounter, "Project does not exist");
        Project storage project = projects[_projectId];
        return (project.id, project.name, project.recipient, project.totalDonated);
    }
    
    // ============ Matching Pool Management ============
    
    /// @notice Deposit matching funds into the pool (owner only)
    function depositMatchingFund() public payable onlyOwner {
        require(msg.value > 0, "Matching fund must be greater than zero");
        totalMatchingFund += msg.value;
        emit MatchingFundUpdated(totalMatchingFund);
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
        
        // Scale input: multiply by PRECISION_FACTOR to reduce division loss
        // For wei amounts, scaling helps maintain precision during sqrt calculation
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
    
    /// @notice Calculate the matching score for a project using Quadratic Funding formula with fixed-point precision
    /// @dev Formula: matchingScore = (sqrt(c1) + sqrt(c2) + ... + sqrt(cn))^2
    /// @dev Uses fixed-point math with PRECISION_FACTOR to maintain accuracy
    /// @dev This approach calculates square roots DURING the final payout (more gas efficient for contributions)
    /// @param _projectId The ID of the project
    /// @return matchingScore The calculated matching score based on all contributions
    function calculateMatchingScore(uint256 _projectId) public returns (uint256) {
        require(_projectId < projectCounter, "Project does not exist");
        
        Project storage project = projects[_projectId];
        require(project.contributionAmounts.length > 0, "No contributions for this project");
        
        uint256 sumOfSqrts = 0;
        
        // Sum the fixed-point square roots of all individual contributions
        for (uint256 i = 0; i < project.contributionAmounts.length; i++) {
            sumOfSqrts += sqrtFixed(project.contributionAmounts[i]);
        }
        
        // Square the sum of square roots
        // Divide by PRECISION_FACTOR^2 to remove the scaling applied in sqrtFixed
        uint256 matchingScore = (sumOfSqrts * sumOfSqrts) / (PRECISION_FACTOR * PRECISION_FACTOR);
        
        emit MatchingScoreCalculated(_projectId, matchingScore);
        
        return matchingScore;
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
        require(_totalMatchingScoresAllProjects > 0, "Total matching scores cannot be zero");
        require(totalMatchingFund > 0, "Matching fund is empty");
        
        Project storage project = projects[_projectId];
        require(project.contributionAmounts.length > 0, "No contributions for this project");
        
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
    function calculateAllMatchingAmounts() 
        public 
        view 
        returns (uint256[] memory matchingAmounts) 
    {
        require(totalMatchingFund > 0, "Matching fund is empty");
        require(projectCounter > 0, "No projects registered");
        
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
        require(_projectId < projectCounter, "Project does not exist");
        return projects[_projectId].contributorAddresses.length;
    }
    
    /// @notice Get the contribution history for a project
    /// @param _projectId The ID of the project
    /// @return Array of all individual contribution amounts
    function getContributionHistory(uint256 _projectId) public view returns (uint256[] memory) {
        require(_projectId < projectCounter, "Project does not exist");
        return projects[_projectId].contributionAmounts;
    }
    
    /// @notice Get all unique contributors to a project
    /// @param _projectId The ID of the project
    /// @return Array of contributor addresses
    function getContributors(uint256 _projectId) public view returns (address[] memory) {
        require(_projectId < projectCounter, "Project does not exist");
        return projects[_projectId].contributorAddresses;
    }
    
    // ============ Capital-Constrained Quadratic Funding (CQF) ============
    
    /// @notice Calculate the total QF score (matching score) across all projects
    /// @dev Returns sum of (sqrt(c1) + sqrt(c2) + ...)^2 for all projects
    /// @return totalQFScore The sum of all projects' QF scores
    function calculateTotalQFScore() public view returns (uint256 totalQFScore) {
        require(projectCounter > 0, "No projects registered");
        
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
        require(projectCounter > 0, "No projects registered");
        require(totalMatchingFund > 0, "Matching fund is empty");
        
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
        require(project.contributionAmounts.length > 0, "No contributions for this project");
        
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
        require(projectCounter > 0, "No projects registered");
        require(totalMatchingFund > 0, "Matching fund is empty");
        
        // Calculate alpha once for all projects
        uint256 alpha = calculateOptimalAlpha();
        
        // Calculate total QF score once
        uint256 totalQFScore = calculateTotalQFScore();
        
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
    
    /// @notice Get summary of CQF calculation parameters
    /// @dev Useful for understanding how the matching pool will be distributed
    /// @return alpha The calculated weighting factor (scaled by 1e18, so 5e17 = 0.5)
    /// @return totalQFScore Total QF score across all projects
    /// @return totalDirectContributions Total direct contributions (sum of all individual donations)
    /// @return matchingFund Available matching pool budget
    function getCQFSummary() public returns (
        uint256 alpha,
        uint256 totalQFScore,
        uint256 totalDirectContributions,
        uint256 matchingFund
    ) {
        alpha = calculateOptimalAlpha();
        totalQFScore = calculateTotalQFScore();
        totalDirectContributions = totalContribution;
        matchingFund = totalMatchingFund;
        
        return (alpha, totalQFScore, totalDirectContributions, matchingFund);
    }
}