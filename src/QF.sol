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
    
    /// @notice Calculate the matching score for a project using Quadratic Funding formula
    /// @dev Formula: matchingScore = (sqrt(c1) + sqrt(c2) + ... + sqrt(cn))^2
    /// @dev This approach calculates square roots DURING the final payout (more gas efficient for contributions)
    /// @param _projectId The ID of the project
    /// @return matchingScore The calculated matching score based on all contributions
    function calculateMatchingScore(uint256 _projectId) public returns (uint256) {
        require(_projectId < projectCounter, "Project does not exist");
        
        Project storage project = projects[_projectId];
        require(project.contributionAmounts.length > 0, "No contributions for this project");
        
        uint256 sumOfSqrts = 0;
        
        // Sum the square roots of all individual contributions
        for (uint256 i = 0; i < project.contributionAmounts.length; i++) {
            sumOfSqrts += sqrt(project.contributionAmounts[i]);
        }
        
        // Square the sum of square roots
        uint256 matchingScore = sumOfSqrts * sumOfSqrts;
        
        emit MatchingScoreCalculated(_projectId, matchingScore);
        
        return matchingScore;
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
}