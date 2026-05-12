// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/QF.sol";

/**
 * @title QuadraticFundingDeployer
 * @notice Deployment script for QF contract with multi-network support
 * 
 * Usage:
 * Local (Anvil):
 *   forge script script/QF.s.sol --rpc-url http://localhost:8545 --broadcast
 * 
 * Testnet (Sepolia):
 *   forge script script/QF.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 * 
 * With environment variables:
 *   DEPLOY_INITIAL_MATCH=10  (ETH for initial matching pool)
 */
contract QuadraticFundingDeployer is Script {
    
    // ============ State Variables ============
    QuadraticFunding public qf;
    address public deployer;
    
    // Network configuration
    struct NetworkConfig {
        string name;
        string rpcUrl;
        uint256 chainId;
    }
    
    // ============ Events ============
    event DeploymentStarted(address indexed deployer, uint256 chainId);
    event ContractDeployed(address indexed contractAddress, uint256 initialMatchingPool);
    event DeploymentComplete(address indexed contractAddress, uint256 timestamp);
    
    // ============ Main Deployment Function ============
    function run() public {
        deployer = msg.sender;
        
        // Get environment configuration
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 initialMatch = vm.envOr("DEPLOY_INITIAL_MATCH", uint256(0));
        
        emit DeploymentStarted(deployer, block.chainid);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy QF contract
        qf = new QuadraticFunding();
        
        // Initialize with matching pool if specified
        if (initialMatch > 0) {
            qf.depositMatchingFund{value: initialMatch * 1 ether}();
            console.log("Initial matching fund deposited: %s ETH", initialMatch);
        }
        
        vm.stopBroadcast();
        
        emit ContractDeployed(address(qf), initialMatch);
        
        // Log deployment details
        console.log("=====================================");
        console.log("QF Contract Deployed Successfully");
        console.log("=====================================");
        console.log("Contract Address:", address(qf));
        console.log("Deployer Address:", deployer);
        console.log("Network Chain ID:", block.chainid);
        console.log("Timestamp:", block.timestamp);
        console.log("=====================================");
    }
    
    // ============ Getter Functions ============
    function getDeployedAddress() public view returns (address) {
        return address(qf);
    }
}
