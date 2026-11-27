// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../contracts/TapeRent.sol";
import "../contracts/MockCircuit.sol";

/// @notice Attacker used for the reentrancy test: on receiving an ETH refund
///         it tries (via try/catch, so the outer call can still complete) to
///         re-enter endEarly. A correct ReentrancyGuard makes the inner call
///         revert, so the attacker is paid exactly once.
contract RefundReentrancyAttacker is IERC721Receiver {
    TapeRent public rent;
    uint256 public listingId;
    uint256 public reenterAttempts;
    uint256 public reenterSuccesses;

    constructor(TapeRent _rent) {
        rent = _rent;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setListing(uint256 id) external {
        listingId = id;
    }

    receive() external payable {
        reenterAttempts++;
        try rent.endEarly(listingId) {
            reenterSuccesses++;
        } catch {}
    }
}

contract TapeRentTest is Test {
    TapeRent public rent;
    MockCircuit public circuit;

    address owner = address(0xA11CE);
    address renter = address(0xB0B);
    address feeRecipient = address(0xFEE);
    address stranger = address(0x57A);

    uint256 constant PRICE = 0.1 ether;
    uint256 constant MAX_DAYS = 30;

    function setUp() public {
        rent = new TapeRent(feeRecipient);
        circuit = new MockCircuit();

        vm.deal(owner, 100 ether);
        vm.deal(renter, 100 ether);
        vm.deal(stranger, 100 ether);

        // owner mints a mock circuit #1
        vm.prank(owner);
        circuit.mintDemo(2, 1);
    }

    function _list() internal returns (uint256 id) {
        vm.prank(owner);
        circuit.approve(address(rent), 1);
        vm.prank(owner);
        id = rent.list(address(circuit), 1, PRICE, MAX_DAYS);
    }

    function _rent(uint256 id, uint256 numDays) internal {
        vm.prank(renter);
        rent.rent{value: PRICE * numDays}(id, numDays);
    }

    // ---------------- list ----------------

    function testListMovesNftIntoEscrow() public {
        uint256 id = _list();
        assertEq(circuit.ownerOf(1), address(rent));
        TapeRent.Listing memory l = rent.getListing(id);
        assertEq(l.owner, owner);
        assertEq(l.pricePerDay, PRICE);
        assertTrue(l.active);
    }

    function testListRevertsWhenNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(TapeRent.NotCircuitOwner.selector);
        rent.list(address(circuit), 1, PRICE, MAX_DAYS);
    }

    function testListRevertsForNonexistentToken() public {
        vm.prank(owner);
        vm.expectRevert(); // ownerOf reverts for a token that does not exist
        rent.list(address(circuit), 999, PRICE, MAX_DAYS);
    }

    function testListRevertsZeroPriceAndZeroMaxDays() public {
        vm.prank(owner);
        circuit.approve(address(rent), 1);
        vm.prank(owner);
        vm.expectRevert(TapeRent.ZeroPrice.selector);
        rent.list(address(circuit), 1, 0, MAX_DAYS);

        vm.prank(owner);
        vm.expectRevert(TapeRent.ZeroMaxDays.selector);
        rent.list(address(circuit), 1, PRICE, 0);
    }

    function testDoubleListReverts() public {
        _list();
        vm.prank(owner);
        vm.expectRevert(TapeRent.AlreadyListed.selector);
        rent.list(address(circuit), 1, PRICE, MAX_DAYS);
    }

    // ---------------- rent ----------------

    function testRentRecordsRenterAndExpiryAndFee() public {
        uint256 id = _list();
        uint256 feeBefore = feeRecipient.balance;
        uint256 t0 = block.timestamp;
        _rent(id, 10);

        (address r, uint256 exp, bool active) = rent.rentalOf(address(circuit), 1);
        assertEq(r, renter);
        assertEq(exp, t0 + 10 days);
        assertTrue(active);
        assertTrue(rent.isRented(address(circuit), 1));
        // fee 2.5% of 1 OKB = 0.025 OKB to feeRecipient; rest held in escrow
        assertEq(feeRecipient.balance - feeBefore, 0.025 ether);
        assertEq(address(rent).balance, 0.975 ether);
    }

    function testRentZeroDaysReverts() public {
        uint256 id = _list();
        vm.prank(renter);
        vm.expectRevert(TapeRent.ZeroDays.selector);
        rent.rent{value: 0}(id, 0);
    }

    function testRentBeyondMaxDaysReverts() public {
        uint256 id = _list();
        vm.prank(renter);
        vm.expectRevert(TapeRent.ExceedsMaxDays.selector);
        rent.rent{value: PRICE * 31}(id, 31);
    }

    function testRentWrongPaymentReverts() public {
        uint256 id = _list();
        vm.prank(renter);
        vm.expectRevert(abi.encodeWithSelector(TapeRent.WrongPayment.selector, PRICE * 5, PRICE * 4));
        rent.rent{value: PRICE * 4}(id, 5);
    }

    function testRentAlreadyRentedReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.prank(stranger);
        vm.expectRevert(TapeRent.AlreadyRented.selector);
        rent.rent{value: PRICE * 5}(id, 5);
    }

    // ---------------- return ----------------

    function testReturnAfterExpiryPaysOwnerAndReturnsNft() public {
        uint256 id = _list();
        _rent(id, 5);
        uint256 ownerBefore = owner.balance;

        vm.warp(block.timestamp + 5 days + 1);
        // anyone may call returnCircuit after expiry
        vm.prank(stranger);
        rent.returnCircuit(id);

        assertEq(circuit.ownerOf(1), owner);
        assertEq(owner.balance - ownerBefore, 0.4875 ether); // 0.5 - 2.5% fee
        assertEq(address(rent).balance, 0);
        (, , bool active) = rent.rentalOf(address(circuit), 1);
        assertFalse(active);
    }

    function testReturnBeforeExpiryReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.prank(stranger);
        vm.expectRevert(TapeRent.NotExpired.selector);
        rent.returnCircuit(id);
    }

    function testReturnBeforeExpiryByOwnerAlsoReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.warp(block.timestamp + 1 days);
        vm.prank(owner);
        vm.expectRevert(TapeRent.NotExpired.selector);
        rent.returnCircuit(id);
    }

    function testReturnAfterExpiryByAnyoneWorksEvenIfRenterGone() public {
        uint256 id = _list();
        _rent(id, 2);
        vm.warp(block.timestamp + 30 days);
        rent.returnCircuit(id); // called by the test contract itself
        assertEq(circuit.ownerOf(1), owner);
    }

    // ---------------- cancel ----------------

    function testCancelReturnsNftWhenNotRented() public {
        uint256 id = _list();
        vm.prank(owner);
        rent.cancelListing(id);
        assertEq(circuit.ownerOf(1), owner);
        assertFalse(rent.getListing(id).active);
    }

    function testCancelByNonOwnerReverts() public {
        uint256 id = _list();
        vm.prank(stranger);
        vm.expectRevert(TapeRent.NotListingOwner.selector);
        rent.cancelListing(id);
    }

    function testCancelWhileRentedReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.prank(owner);
        vm.expectRevert(TapeRent.AlreadyRented.selector);
        rent.cancelListing(id);
    }

    // ---------------- extend ----------------

    function testExtendAddsDaysAndEscrow() public {
        uint256 id = _list();
        _rent(id, 5);
        uint256 t0 = block.timestamp;
        vm.prank(renter);
        rent.extend{value: PRICE * 3}(id, 3);
        TapeRent.Listing memory l = rent.getListing(id);
        assertEq(l.expiresAt, t0 + 8 days);
        assertEq(l.rentedDays, 8);
        assertEq(l.escrow, 0.78 ether); // 0.4875 (rent 5d) + 0.2925 (extend 3d)
    }

    function testExtendBeyondMaxDaysReverts() public {
        uint256 id = _list();
        _rent(id, 28);
        vm.prank(renter);
        vm.expectRevert(TapeRent.ExceedsMaxDays.selector);
        rent.extend{value: PRICE * 3}(id, 3);
    }

    function testExtendByNonRenterReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.prank(stranger);
        vm.expectRevert(TapeRent.NotRenter.selector);
        rent.extend{value: PRICE}(id, 1);
    }

    function testExtendAfterExpiryReverts() public {
        uint256 id = _list();
        _rent(id, 5);
        vm.warp(block.timestamp + 6 days);
        vm.prank(renter);
        vm.expectRevert(TapeRent.AlreadyExpired.selector);
        rent.extend{value: PRICE}(id, 1);
    }

    // ---------------- endEarly ----------------

    function testEndEarlyRefundsUnusedFullDaysFeeFree() public {
        uint256 id = _list();
        _rent(id, 10); // paid 1 OKB, fee 0.025, escrow 0.975
        // 2.5 days in: 7 full days unused -> refund 0.7 OKB, owner gets 0.275
        vm.warp(block.timestamp + 2 days + 12 hours);
        uint256 renterBefore = renter.balance;
        uint256 ownerBefore = owner.balance;
        vm.prank(renter);
        rent.endEarly(id);
        assertEq(renter.balance - renterBefore, 0.7 ether);
        assertEq(owner.balance - ownerBefore, 0.275 ether);
        assertEq(circuit.ownerOf(1), owner);
        assertEq(address(rent).balance, 0);
    }

    function testEndEarlyByNonRenterReverts() public {
        uint256 id = _list();
        _rent(id, 10);
        vm.prank(stranger);
        vm.expectRevert(TapeRent.NotRenter.selector);
        rent.endEarly(id);
    }

    function testEndEarlyAfterExpiryReverts() public {
        uint256 id = _list();
        _rent(id, 2);
        vm.warp(block.timestamp + 3 days);
        vm.prank(renter);
        vm.expectRevert(TapeRent.AlreadyExpired.selector);
        rent.endEarly(id);
    }

    function testEndEarlyWithNoFullDayLeftRefundsZero() public {
        uint256 id = _list();
        _rent(id, 2);
        vm.warp(block.timestamp + 1 days + 12 hours); // 0 full days left
        uint256 renterBefore = renter.balance;
        vm.prank(renter);
        rent.endEarly(id);
        assertEq(renter.balance, renterBefore); // no refund
        assertEq(circuit.ownerOf(1), owner);
    }

    // ---------------- reentrancy ----------------

    function testReentrancyOnRefundPaysExactlyOnce() public {
        RefundReentrancyAttacker attacker = new RefundReentrancyAttacker(rent);
        // attacker mints its own circuit and lists it
        vm.prank(address(attacker));
        uint256 tokenId = circuit.mintDemo(2, 1);
        vm.prank(address(attacker));
        circuit.approve(address(rent), tokenId);
        vm.prank(address(attacker));
        uint256 id = rent.list(address(circuit), tokenId, PRICE, MAX_DAYS);
        attacker.setListing(id);

        // attacker rents its own listing (as renter) for 10 days
        vm.deal(address(attacker), 10 ether);
        vm.prank(address(attacker));
        rent.rent{value: PRICE * 10}(id, 10);

        vm.warp(block.timestamp + 1 days); // 9 full days unused -> refund 0.9
        uint256 balBefore = address(attacker).balance;
        vm.prank(address(attacker));
        rent.endEarly(id);

        // attacker is BOTH renter (refund 0.9) and owner (0.075 net rent),
        // so it receives 0.975 in total — but the re-entrant inner call
        // must still have failed exactly once.
        assertEq(address(attacker).balance - balBefore, 0.975 ether);
        assertEq(attacker.reenterAttempts(), 2); // refund + owner payout both hit receive()
        assertEq(attacker.reenterSuccesses(), 0); // every inner call reverted
        assertFalse(rent.getListing(id).active);
    }

    // ---------------- views / config ----------------

    function testRentalOfUnlistedReturnsEmpty() public {
        (address r, uint256 exp, bool active) = rent.rentalOf(address(circuit), 1);
        assertEq(r, address(0));
        assertEq(exp, 0);
        assertFalse(active);
    }

    function testIsRentedFalseAfterExpiry() public {
        uint256 id = _list();
        _rent(id, 2);
        vm.warp(block.timestamp + 3 days);
        assertFalse(rent.isRented(address(circuit), 1));
        // listing still active until returnCircuit is called — NFT stays escrowed
        assertTrue(rent.getListing(id).active);
    }

    function testRelistAfterReturnWorks() public {
        uint256 id = _list();
        _rent(id, 2);
        vm.warp(block.timestamp + 3 days);
        rent.returnCircuit(id);
        vm.prank(owner);
        circuit.approve(address(rent), 1);
        vm.prank(owner);
        uint256 id2 = rent.list(address(circuit), 1, PRICE, MAX_DAYS);
        assertTrue(id2 != id);
        assertEq(circuit.ownerOf(1), address(rent));
    }

    function testFeeConfig() public {
        assertEq(rent.feeBps(), 250);
        assertEq(rent.feeRecipient(), feeRecipient);
        vm.prank(address(this)); // test contract is the deployer/owner
        rent.setFeeBps(500);
        assertEq(rent.feeBps(), 500);
        vm.prank(address(this));
        vm.expectRevert(TapeRent.FeeTooHigh.selector);
        rent.setFeeBps(1001);
        vm.prank(stranger);
        vm.expectRevert();
        rent.setFeeBps(100);
    }

    function testDirectOkbTransferReverts() public {
        (bool ok,) = address(rent).call{value: 1 ether}("");
        assertFalse(ok);
    }

    function testRescueStrayOnlyForUnlistedTokens() public {
        // send a circuit directly to TapeRent (not via list)
        vm.prank(owner);
        circuit.safeTransferFrom(owner, address(rent), 1);
        assertEq(circuit.ownerOf(1), address(rent));
        // contract owner (test contract) rescues it back
        rent.rescueStray(address(circuit), 1, owner);
        assertEq(circuit.ownerOf(1), owner);

        // a listed token cannot be rescued
        _list();
        vm.expectRevert(TapeRent.AlreadyListed.selector);
        rent.rescueStray(address(circuit), 1, owner);
    }
}
