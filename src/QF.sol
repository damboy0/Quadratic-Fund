// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

// @title Quadratic Funding
// @author damboy.eth 

// @notice A simple implementation of quadratic funding for public goods
// @dev This is a very basic implementation and should not be used in production without further testing and security audits
// @dev This implementation does not include any mechanisms for preventing Sybil attacks or other forms of manipulation, and should be used with caution in a real-world setting
// @dev This implementation is intended for educational purposes only and should not be used in production without further testing and security audits




contract QuadraticFunding {
    // something to keep track of total matching funds available
    uint256 public totalMatchingFund; 
    // something to keep track of total contributions for each project
    uint256 public totalProjectContribution;
    // something to keep track of total contributions 
    uint256 public totalContribution;
    // something to keep track of total contributions for each contributor 
    mapping (uint256 => address) public totalContribitionOfAddress;

    constructor() {
        
    }
    // USERS
    // function to create join a funding and add your project with details 
    function createProjectProfile(uint256 id, uint256 ) public {

    }
    // a function for to know total contribitions for a project 
    // function for calculate matching fund for a project using the QF formular to derive what will be gotten by the project from the matching pool
    // function for to know 


    // For fund campaign 
    // create funding where projects can join 
    // set a time/duration of QF peroid and description


    //For Donors 
    // get list of the project to donate to ubder a certain funding or different funding
    // do a sybil check for donors so as they are not part of gaming the system

}