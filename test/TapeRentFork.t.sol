// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/TapeRent.sol";

interface ITapeOutFactory {
    function cpuCount() external view returns (uint256);
    function cpus(uint256) external view returns (address);
    function deployFee() external view returns (uint256);
    function protocolFee() external view returns (uint256);
    function isSealed() external view returns (bool);
}

interface ICircuit {
    function ownerOf(uint256) external view returns (address);
    function nextId() external view returns (uint256);
    function circuitInfo(uint256)
        external
        view
        returns (uint32 nIn, uint32 nOut, uint32 nState, uint256 gateCount);
    function approve(address, uint256) external;
}

/// @notice Fork test against X Layer mainnet (chain 196) — READ-ONLY plus a
///         local, non-broadcast simulation. No transaction is ever sent to
///         mainnet: the fork runs on a local anvil instance.
///         Run: forge test --match-contract TapeRentForkTest --fork-url https://rpc.xlayer.tech
///         (or set [rpc_endpoints] xlayer and use --fork-url xlayer)
contract TapeRentForkTest is Test {
    address constant FACTORY = 0x1f09DAeFA827f02CBb40967cc91b259763760761;
    address constant CPU0_CIRCUIT = 0x839bdD6fa7A66416A609A735e11DE5411B98574e;
    address constant VIPERX = 0xb57b56034e2dc25161e2512CfC40b24EA3bee1Fb;
    address constant VIPERX_OWNER = 0x9f718b338Ccc69B6AC211Dc8239548E43095813a; // ownerOf(ViperX #1)

    TapeRent public rent;

    function setUp() public {
        rent = new TapeRent(address(0xFEE)); // EOA fee recipient: test contract has no receive()
    }

    function testForkReadsFactoryLive() public {
        ITapeOutFactory factory = ITapeOutFactory(FACTORY);
        uint256 count = factory.cpuCount();
        emit log_named_uint("cpuCount", count);
        assertGe(count, 400); // 451 on 25 Nov 2026
        assertEq(factory.cpus(0), CPU0_CIRCUIT);
        assertGt(factory.deployFee(), 0);
        assertFalse(factory.isSealed());
    }

    function testForkReadsCpu0CircuitLive() public {
        ICircuit cpu0 = ICircuit(CPU0_CIRCUIT);
        assertGe(cpu0.nextId(), 100); // 105 on 25 Nov 2026
        (uint32 nIn, uint32 nOut, uint32 nState, uint256 gates) = cpu0.circuitInfo(1);
        assertEq(nIn, 2);
        assertEq(nOut, 1);
        assertEq(nState, 0);
        assertEq(gates, 4);
    }

    function testForkReadsViperXOwnerLive() public {
        assertEq(ICircuit(VIPERX).ownerOf(1), VIPERX_OWNER);
    }

    /// @notice Full rental flow with a REAL TapeOut circuit NFT (ViperX #1)
    ///         on a mainnet fork: impersonate its owner, list it in TapeRent,
    ///         rent it from another account, warp past expiry, return it.
    ///         Nothing is broadcast; everything happens in the local fork.
    function testForkRealCircuitListRentReturn() public {
        // 1. List the real ViperX #1 as its real owner (impersonated).
        vm.startPrank(VIPERX_OWNER);
        ICircuit(VIPERX).approve(address(rent), 1);
        uint256 listingId = rent.list(VIPERX, 1, 0.01 ether, 30);
        vm.stopPrank();

        assertEq(ICircuit(VIPERX).ownerOf(1), address(rent));

        // 2. Rent it from a different account for 7 days.
        address renter = address(0xB0B);
        vm.deal(renter, 10 ether);
        vm.prank(renter);
        rent.rent{value: 0.07 ether}(listingId, 7);

        (address r, uint256 exp, bool active) = rent.rentalOf(VIPERX, 1);
        assertEq(r, renter);
        assertTrue(active);
        assertEq(exp, block.timestamp + 7 days);
        assertTrue(rent.isRented(VIPERX, 1));

        // 3. Early return is blocked; after expiry anyone can return it.
        vm.expectRevert(TapeRent.NotExpired.selector);
        rent.returnCircuit(listingId);

        vm.warp(block.timestamp + 7 days + 1);
        uint256 ownerBalBefore = VIPERX_OWNER.balance;
        rent.returnCircuit(listingId);

        assertEq(ICircuit(VIPERX).ownerOf(1), VIPERX_OWNER);
        // 0.07 OKB minus 2.5% fee = 0.06825 OKB to the owner
        assertEq(VIPERX_OWNER.balance - ownerBalBefore, 0.06825 ether);
    }
}
