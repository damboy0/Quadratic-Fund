// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/QF.sol";

contract QuadraticFundingTest is Test {
    QuadraticFunding qf;
    
    // Test addresses
    address owner = address(0x1);
    address projectA = address(0x2);
    address projectB = address(0x3);
    address donor1 = address(0x10);
    address donor2 = address(0x11);
    address donor3 = address(0x12);
    
    function setUp() public {
        vm.prank(owner);
        qf = new QuadraticFunding();
        
        // Fund test addresses
        vm.deal(donor1, 100 ether);
        vm.deal(donor2, 100 ether);
        vm.deal(donor3, 100 ether);
        vm.deal(owner, 1000 ether);
    }
    
    // ============ Helper function ============
    
    function _setupRound() internal {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.registerProject("Project B", projectB);
        qf.depositMatchingFund{value: 50 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
    }
    
    // ============ Project Registration Tests ============
    
    function test_registerProjectSuccessfully() public {
        vm.prank(owner);
        uint256 projectId = qf.registerProject("Test Project", projectA);
        
        assertEq(projectId, 0);
        assertEq(qf.projectCounter(), 1);
        
        (uint256 id, string memory name, address recipient, uint256 totalDonated) = qf.getProject(0);
        assertEq(id, 0);
        assertEq(name, "Test Project");
        assertEq(recipient, projectA);
        assertEq(totalDonated, 0);
    }
    
    function test_registerMultipleProjects() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.registerProject("Project B", projectB);
        vm.stopPrank();
        
        assertEq(qf.projectCounter(), 2);
        
        (uint256 id1, string memory name1, address recipient1, ) = qf.getProject(0);
        (uint256 id2, string memory name2, address recipient2, ) = qf.getProject(1);
        
        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(recipient1, projectA);
        assertEq(recipient2, projectB);
    }
    
    function test_rejectProjectWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid recipient");
        qf.registerProject("Bad Project", address(0));
    }
    
    function test_rejectProjectWithEmptyName() public {
        vm.prank(owner);
        vm.expectRevert("No name");
        qf.registerProject("", projectA);
    }
    
    // ============ Matching Fund Tests ============
    
    function test_depositMatchingFundAsOwner() public {
        vm.prank(owner);
        qf.depositMatchingFund{value: 10 ether}();
        
        assertEq(qf.totalMatchingFund(), 10 ether);
        assertEq(qf.remainingMatchingFund(), 10 ether);
    }
    
    function test_depositMultipleMatchingFunds() public {
        vm.startPrank(owner);
        qf.depositMatchingFund{value: 10 ether}();
        qf.depositMatchingFund{value: 5 ether}();
        vm.stopPrank();
        
        assertEq(qf.totalMatchingFund(), 15 ether);
    }
    
    function test_rejectNonOwnerDeposit() public {
        vm.prank(donor1);
        vm.expectRevert("Owner only");
        qf.depositMatchingFund{value: 10 ether}();
    }
    
    // ============ Round Management Tests ============
    
    function test_startRoundSuccessfully() public {
        vm.prank(owner);
        qf.startRound(7 days);
        
        assertTrue(qf.roundActive());
        assertTrue(qf.isRoundActive());
    }
    
    function test_roundTimeRemaining() public {
        vm.prank(owner);
        qf.startRound(7 days);
        
        uint256 remaining = qf.getRoundTimeRemaining();
        assertGt(remaining, 0);
        assertLe(remaining, 7 days);
    }
    
    function test_endRound() public {
        vm.startPrank(owner);
        qf.startRound(7 days);
        qf.endRound();
        vm.stopPrank();
        
        assertFalse(qf.roundActive());
    }
    
    function test_rejectRoundStartWhenAlreadyActive() public {
        vm.startPrank(owner);
        qf.startRound(7 days);
        
        vm.expectRevert("Round active");
        qf.startRound(7 days);
        vm.stopPrank();
    }
    
    function test_roundTimeExpires() public {
        vm.prank(owner);
        qf.startRound(1 days);
        
        // Warp time forward
        vm.warp(block.timestamp + 2 days);
        
        assertFalse(qf.isRoundActive());
    }
    
    // ============ Contribution Tests (No Sybil Resistance) ============
    
    function test_contributeToProjectDuringRound() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 50 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        assertEq(qf.getContributorAmount(0, donor1), 1 ether);
        assertEq(qf.getProjectTotalDonated(0), 1 ether);
    }
    
    function test_multipleContributionsToSameProject() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 50 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.startPrank(donor1);
        qf.contribute{value: 1 ether}(0);
        qf.contribute{value: 2 ether}(0);
        vm.stopPrank();
        
        assertEq(qf.getContributorAmount(0, donor1), 3 ether);
        assertEq(qf.getProjectTotalDonated(0), 3 ether);
    }
    
    function test_multipleContributorsToProject() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 50 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        vm.prank(donor2);
        qf.contribute{value: 2 ether}(0);
        
        vm.prank(donor3);
        qf.contribute{value: 3 ether}(0);
        
        assertEq(qf.getProjectTotalDonated(0), 6 ether);
        assertEq(qf.totalContribution(), 6 ether);
    }
    
    function test_rejectContributionOutsideRound() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(donor1);
        vm.expectRevert("Ended");
        qf.contribute{value: 1 ether}(0);
    }
    
    function test_rejectContributionWithoutRound() public {
        vm.prank(owner);
        qf.registerProject("Project A", projectA);
        
        vm.prank(donor1);
        vm.expectRevert("No round");
        qf.contribute{value: 1 ether}(0);
    }
    
    function test_rejectZeroContribution() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        vm.expectRevert("Zero contribution");
        qf.contribute{value: 0}(0);
    }
    
    function test_trackUniqueContributors() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        vm.prank(donor2);
        qf.contribute{value: 1 ether}(0);
        
        assertEq(qf.getUniqueContributorCount(0), 2);
        
        address[] memory contributors = qf.getContributors(0);
        assertEq(contributors.length, 2);
    }
    
    // ============ Sybil Resistance Tests ============
    
    function test_enableWhitelistMode() public {
        vm.prank(owner);
        qf.enableWhitelistMode();
        
        (, bool whitelistEnabled, ) = qf.getSybilResistanceConfig();
        assertTrue(whitelistEnabled);
    }
    
    function test_verifyAddressInWhitelist() public {
        vm.startPrank(owner);
        qf.enableWhitelistMode();
        qf.verifyAddress(donor1);
        vm.stopPrank();
        
        assertTrue(qf.isAddressVerified(donor1));
    }
    
    function test_batchVerifyAddresses() public {
        address[] memory addresses = new address[](3);
        addresses[0] = donor1;
        addresses[1] = donor2;
        addresses[2] = donor3;
        
        vm.startPrank(owner);
        qf.enableWhitelistMode();
        qf.verifyAddresses(addresses);
        vm.stopPrank();
        
        assertTrue(qf.isAddressVerified(donor1));
        assertTrue(qf.isAddressVerified(donor2));
        assertTrue(qf.isAddressVerified(donor3));
    }
    
    function test_unverifyAddress() public {
        vm.startPrank(owner);
        qf.enableWhitelistMode();
        qf.verifyAddress(donor1);
        qf.unverifyAddress(donor1);
        vm.stopPrank();
        
        assertFalse(qf.isAddressVerified(donor1));
    }
    
    function test_rejectContributionFromUnverifiedAddress() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.enableWhitelistMode();
        qf.verifyAddress(donor1);
        qf.startRound(7 days);
        vm.stopPrank();
        
        // donor1 is verified
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        // donor2 is not verified
        vm.prank(donor2);
        vm.expectRevert("Not whitelisted");
        qf.contribute{value: 1 ether}(0);
    }
    
    function test_disableWhitelistMode() public {
        vm.startPrank(owner);
        qf.enableWhitelistMode();
        qf.disableWhitelistMode();
        vm.stopPrank();
        
        (, bool whitelistEnabled, ) = qf.getSybilResistanceConfig();
        assertFalse(whitelistEnabled);
    }
    
    // ============ CQF Calculation Tests ============
    
    function test_calculateTotalQFScore() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.registerProject("Project B", projectB);
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.startPrank(donor1);
        qf.contribute{value: 1 ether}(0);
        qf.contribute{value: 1 ether}(0);
        vm.stopPrank();
        
        vm.prank(donor2);
        qf.contribute{value: 1 ether}(1);
        
        uint256 qfScore = qf.calculateTotalQFScore();
        assertGt(qfScore, 0);
    }
    
    function test_calculateOptimalAlpha() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        uint256 alpha = qf.calculateOptimalAlpha();
        assertGt(alpha, 0);
        assertLe(alpha, 1e18); // Alpha should be between 0 and 1
    }
    
    function test_calculateCQFPayoutForProject() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        vm.prank(donor2);
        qf.contribute{value: 1 ether}(0);
        
        uint256 payout = qf.calculateCQFPayout(0);
        // Payout should be positive
        assertGt(payout, 0);
    }
    
    function test_calculateAllCQFPayouts() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.registerProject("Project B", projectB);
        qf.depositMatchingFund{value: 20 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.startPrank(donor1);
        qf.contribute{value: 1 ether}(0);
        qf.contribute{value: 2 ether}(0);
        vm.stopPrank();
        
        vm.prank(donor2);
        qf.contribute{value: 1 ether}(1);
        
        uint256[] memory payouts = qf.calculateAllCQFPayouts();
        assertEq(payouts.length, 2);
        assertGt(payouts[0], 0);
        assertGt(payouts[1], 0);
    }
    
    function test_getCQFSummary() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        (uint256 alpha, uint256 qfScore, uint256 totalDirect, uint256 matchFund) = qf.getCQFSummary();
        assertGt(alpha, 0);
        assertGt(qfScore, 0);
        assertEq(totalDirect, 1 ether);
        assertEq(matchFund, 10 ether);
    }
    
    // ============ Round Finalization Tests ============
    
    function test_finalizeRoundSuccessfully() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        assertTrue(qf.isRoundFinalized());
    }
    
    function test_rejectFinalizationBeforeRoundEnds() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Active");
        qf.finalizeRound();
    }
    
    function test_rejectDoubleFinalization() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 2 days);
        
        vm.startPrank(owner);
        qf.finalizeRound();
        
        // After first finalization, the round is no longer active
        // Second finalization attempt should fail (no active round to finalize)
        vm.expectRevert();
        qf.finalizeRound();
        vm.stopPrank();
    }
    
    function test_getFinalizedMatchingAmount() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        uint256 matchingAmount = qf.getFinalizedMatchingAmount(0);
        assertGt(matchingAmount, 0);
    }
    
    function test_getProjectTotalPayout() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        uint256 totalPayout = qf.getProjectTotalPayout(0);
        assertGe(totalPayout, 2 ether); // At least the direct contribution
    }
    
    // ============ Withdrawal Tests ============
    
    function test_withdrawProjectFunds() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        uint256 initialBalance = projectA.balance;
        
        vm.prank(projectA);
        qf.withdrawProjectFunds(0);
        
        uint256 withdrawn = projectA.balance - initialBalance;
        assertGt(withdrawn, 0);
    }
    
    function test_rejectWithdrawalFromNonRecipient() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        vm.prank(donor1);
        vm.expectRevert("Not owner");
        qf.withdrawProjectFunds(0);
    }
    
    function test_rejectWithdrawalBeforeFinalization() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(projectA);
        vm.expectRevert("Not finalized");
        qf.withdrawProjectFunds(0);
    }
    
    function test_getProjectWithdrawnAmount() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        vm.prank(projectA);
        qf.withdrawProjectFunds(0);
        
        uint256 withdrawn = qf.getProjectWithdrawnAmount(0);
        assertGt(withdrawn, 0);
    }
    
    function test_getProjectRemainingWithdrawal() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        uint256 remaining = qf.getProjectRemainingWithdrawal(0);
        assertGt(remaining, 0);
        
        vm.prank(projectA);
        qf.withdrawProjectFunds(0);
        
        uint256 afterWithdraw = qf.getProjectRemainingWithdrawal(0);
        assertEq(afterWithdraw, 0);
    }
    
    function test_recoverUnusedMatchingFunds() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 20 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 0.1 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        uint256 recoverable = qf.getRecoverableMatchingFunds();
        assertGt(recoverable, 0);
        
        uint256 initialBalance = owner.balance;
        vm.prank(owner);
        qf.recoverUnusedMatchingFunds();
        
        uint256 recovered = owner.balance - initialBalance;
        assertEq(recovered, recoverable);
    }
    
    function test_getFinalizationStatus() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 10 ether}();
        qf.startRound(1 days);
        vm.stopPrank();
        
        vm.prank(donor1);
        qf.contribute{value: 1 ether}(0);
        
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        (bool isFinalized, uint256 distributed, uint256 recoverable) = qf.getFinalizationStatus();
        assertTrue(isFinalized);
        assertGt(distributed, 0);
        assertGt(recoverable, 0);
    }
    
    // ============ Edge Cases & Integration Tests ============
    
    function test_endToEndFlow() public {
        // Setup
        vm.startPrank(owner);
        qf.registerProject("Green Energy", projectA);
        qf.registerProject("Education", projectB);
        qf.depositMatchingFund{value: 20 ether}();
        
        // Enable whitelist
        address[] memory verified = new address[](3);
        verified[0] = donor1;
        verified[1] = donor2;
        verified[2] = donor3;
        qf.verifyAddresses(verified);
        qf.enableWhitelistMode();
        
        // Start round
        qf.startRound(7 days);
        vm.stopPrank();
        
        // Contributions
        vm.prank(donor1);
        qf.contribute{value: 2 ether}(0);
        
        vm.prank(donor2);
        qf.contribute{value: 3 ether}(0);
        
        vm.prank(donor3);
        qf.contribute{value: 2 ether}(1);
        
        // Verify state before finalization
        assertEq(qf.getProjectTotalDonated(0), 5 ether);
        assertEq(qf.getProjectTotalDonated(1), 2 ether);
        assertEq(qf.totalContribution(), 7 ether);
        
        // End round and finalize
        vm.warp(block.timestamp + 8 days);
        
        vm.prank(owner);
        qf.finalizeRound();
        
        // Check finalization
        assertTrue(qf.isRoundFinalized());
        
        // Withdrawals
        vm.prank(projectA);
        qf.withdrawProjectFunds(0);
        
        vm.prank(projectB);
        qf.withdrawProjectFunds(1);
        
        // Recovery
        uint256 remaining = qf.getRecoverableMatchingFunds();
        vm.prank(owner);
        if (remaining > 0) {
            qf.recoverUnusedMatchingFunds();
        }
    }
    
    function test_largeNumberOfContributors() public {
        vm.startPrank(owner);
        qf.registerProject("Project A", projectA);
        qf.depositMatchingFund{value: 100 ether}();
        qf.startRound(7 days);
        vm.stopPrank();
        
        // Create and fund many donors
        for (uint256 i = 0; i < 10; i++) {
            address donor = address(uint160(0x100 + i));
            vm.deal(donor, 10 ether);
            
            vm.prank(donor);
            qf.contribute{value: 0.5 ether}(0);
        }
        
        assertEq(qf.getUniqueContributorCount(0), 10);
        assertEq(qf.getProjectTotalDonated(0), 5 ether);
    }
    
    function test_sqrt_precision() public view {
        // Test sqrt calculations for various values
        uint256 val1 = qf.sqrt(4);
        assertEq(val1, 2);
        
        uint256 val2 = qf.sqrt(9);
        assertEq(val2, 3);
        
        uint256 val3 = qf.sqrt(100);
        assertEq(val3, 10);
    }
    
    function test_sqrtFixed_precision() public view {
        // Test fixed-point sqrt
        uint256 result1 = qf.sqrtFixed(1e18);
        assertGt(result1, 0);
        
        uint256 result2 = qf.sqrtFixed(4e18);
        assertGt(result2, result1);
    }
}
