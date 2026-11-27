// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TapeRent — rental marketplace for TapeOut circuit NFTs on X Layer
/// @notice Owners deposit a TapeOut circuit NFT (ERC-721) into escrow and set a
///         price per day. Renters pay in native OKB; the rental right (renter +
///         expiry) is recorded on-chain via `rentalOf`, so any other app can
///         verify who may use a circuit without buying it.
/// @dev Escrow model: rent payments (minus the protocol fee, which is forwarded
///      immediately to feeRecipient) are held in the contract until the rental
///      ends. The owner is paid when the circuit is returned / the rental ends
///      early; unused full days are refunded to the renter on early exit.
///      No oracle, no ERC-20, only native OKB.
/// @custom:warning TapeOut contracts on X Layer are still in a test phase,
///      upgradeable and UNAUDITED, and their owner can change fees at any time.
///      TapeRent itself is also unaudited hackathon code — do not use with
///      high-value assets without a professional audit.
contract TapeRent is ERC721Holder, ReentrancyGuard, Ownable {
    /// @notice Fee in basis points. 250 = 2.5%.
    uint256 public constant MAX_FEE_BPS = 1000; // 10% hard cap
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public feeBps = 250;
    address public feeRecipient;

    uint256 public nextListingId = 1;

    struct Listing {
        address circuit; // TapeOut circuit contract (ERC-721)
        uint256 tokenId;
        address owner; // circuit owner (lister)
        address renter; // address(0) while not rented
        uint256 pricePerDay; // wei (OKB) per day
        uint256 maxDays; // max total rental length
        uint256 rentedDays; // total days rented so far (rent + extensions)
        uint256 expiresAt; // 0 while not rented
        uint256 escrow; // OKB held for this listing (rent minus fee)
        bool active; // true while the NFT sits in this contract
    }

    mapping(uint256 => Listing) public listings;
    /// circuit => tokenId => listingId (0 = not listed)
    mapping(address => mapping(uint256 => uint256)) public listingOfToken;

    event Listed(
        uint256 indexed listingId,
        address indexed circuit,
        uint256 indexed tokenId,
        address owner,
        uint256 pricePerDay,
        uint256 maxDays
    );
    event Rented(
        uint256 indexed listingId,
        address indexed renter,
        uint256 numDays,
        uint256 paid,
        uint256 fee,
        uint256 expiresAt
    );
    event Extended(uint256 indexed listingId, uint256 extraDays, uint256 paid, uint256 fee, uint256 expiresAt);
    event EndedEarly(uint256 indexed listingId, address indexed renter, uint256 refunded, uint256 paidToOwner);
    event Returned(uint256 indexed listingId, address indexed renter, uint256 paidToOwner);
    event Cancelled(uint256 indexed listingId);
    event FeeUpdated(uint256 feeBps, address feeRecipient);

    error ZeroAddress();
    error ZeroPrice();
    error ZeroMaxDays();
    error ZeroDays();
    error NotCircuitOwner();
    error AlreadyListed();
    error NotListed();
    error NotListingOwner();
    error NotRenter();
    error AlreadyRented();
    error NotRented();
    error ExceedsMaxDays();
    error WrongPayment(uint256 expected, uint256 received);
    error NotExpired();
    error AlreadyExpired();
    error FeeTooHigh();

    constructor(address _feeRecipient) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    // ------------------------------------------------------------------
    // Owner (protocol) config
    // ------------------------------------------------------------------

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = _feeBps;
        emit FeeUpdated(feeBps, feeRecipient);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeUpdated(feeBps, feeRecipient);
    }

    // ------------------------------------------------------------------
    // Listing
    // ------------------------------------------------------------------

    /// @notice Deposit a circuit NFT into escrow and list it for rent.
    /// @dev Reverts (via ownerOf) if the token does not exist; reverts if the
    ///      caller is not its owner. The caller must approve this contract
    ///      for the token first (approve / setApprovalForAll).
    function list(address circuitContract, uint256 tokenId, uint256 pricePerDay, uint256 maxDays)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        if (circuitContract == address(0)) revert ZeroAddress();
        if (pricePerDay == 0) revert ZeroPrice();
        if (maxDays == 0) revert ZeroMaxDays();
        if (listingOfToken[circuitContract][tokenId] != 0) revert AlreadyListed();
        // ownerOf reverts for a non-existent token — that is the existence check.
        if (IERC721(circuitContract).ownerOf(tokenId) != msg.sender) revert NotCircuitOwner();

        listingId = nextListingId++;
        listings[listingId] = Listing({
            circuit: circuitContract,
            tokenId: tokenId,
            owner: msg.sender,
            renter: address(0),
            pricePerDay: pricePerDay,
            maxDays: maxDays,
            rentedDays: 0,
            expiresAt: 0,
            escrow: 0,
            active: true
        });
        listingOfToken[circuitContract][tokenId] = listingId;

        IERC721(circuitContract).safeTransferFrom(msg.sender, address(this), tokenId);

        emit Listed(listingId, circuitContract, tokenId, msg.sender, pricePerDay, maxDays);
    }

    /// @notice Cancel an unrented listing; the NFT returns to the owner.
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed();
        if (l.owner != msg.sender) revert NotListingOwner();
        if (l.renter != address(0)) revert AlreadyRented();

        l.active = false;
        listingOfToken[l.circuit][l.tokenId] = 0;

        IERC721(l.circuit).safeTransferFrom(address(this), l.owner, l.tokenId);
        emit Cancelled(listingId);
    }

    // ------------------------------------------------------------------
    // Renting
    // ------------------------------------------------------------------

    /// @notice Rent a listed circuit for `days` days. Exact payment required:
    ///         pricePerDay * days wei in native OKB.
    function rent(uint256 listingId, uint256 numDays) external payable nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed();
        if (l.renter != address(0)) revert AlreadyRented();
        if (numDays == 0) revert ZeroDays();
        if (numDays > l.maxDays) revert ExceedsMaxDays();

        uint256 total = l.pricePerDay * numDays;
        if (msg.value != total) revert WrongPayment(total, msg.value);

        uint256 fee = (total * feeBps) / BPS_DENOMINATOR;
        uint256 net = total - fee;

        l.renter = msg.sender;
        l.rentedDays = numDays;
        l.expiresAt = block.timestamp + numDays * 1 days;
        l.escrow = net;

        if (fee > 0) {
            (bool ok,) = payable(feeRecipient).call{value: fee}("");
            require(ok, "fee transfer failed");
        }

        emit Rented(listingId, msg.sender, numDays, total, fee, l.expiresAt);
    }

    /// @notice Extend an active rental. Only the renter, before expiry.
    function extend(uint256 listingId, uint256 extraDays) external payable nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed();
        if (l.renter != msg.sender) revert NotRenter();
        if (block.timestamp >= l.expiresAt) revert AlreadyExpired();
        if (extraDays == 0) revert ZeroDays();
        if (l.rentedDays + extraDays > l.maxDays) revert ExceedsMaxDays();

        uint256 total = l.pricePerDay * extraDays;
        if (msg.value != total) revert WrongPayment(total, msg.value);

        uint256 fee = (total * feeBps) / BPS_DENOMINATOR;
        l.escrow += total - fee;
        l.rentedDays += extraDays;
        l.expiresAt += extraDays * 1 days;

        if (fee > 0) {
            (bool ok,) = payable(feeRecipient).call{value: fee}("");
            require(ok, "fee transfer failed");
        }

        emit Extended(listingId, extraDays, total, fee, l.expiresAt);
    }

    /// @notice End a rental early. Only the renter, before expiry.
    ///         Unused FULL days are refunded fee-free; the rest goes to the
    ///         owner and the NFT returns to the owner.
    function endEarly(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed();
        if (l.renter != msg.sender) revert NotRenter();
        if (block.timestamp >= l.expiresAt) revert AlreadyExpired();

        uint256 unusedDays = (l.expiresAt - block.timestamp) / 1 days;
        uint256 refund = unusedDays * l.pricePerDay;
        if (refund > l.escrow) refund = l.escrow; // safety, should not happen
        uint256 toOwner = l.escrow - refund;

        address renter = l.renter;
        address owner_ = l.owner;
        address circuit = l.circuit;
        uint256 tokenId = l.tokenId;

        l.active = false;
        l.renter = address(0);
        l.expiresAt = 0;
        l.escrow = 0;
        listingOfToken[circuit][tokenId] = 0;

        if (refund > 0) {
            (bool ok,) = payable(renter).call{value: refund}("");
            require(ok, "refund failed");
        }
        if (toOwner > 0) {
            (bool ok,) = payable(owner_).call{value: toOwner}("");
            require(ok, "owner payout failed");
        }
        IERC721(circuit).safeTransferFrom(address(this), owner_, tokenId);

        emit EndedEarly(listingId, renter, refund, toOwner);
    }

    /// @notice Return a circuit after its rental expired. Callable by anyone
    ///         so funds/NFTs can never get stuck if the renter disappears.
    ///         Pays the escrowed rent to the owner and returns the NFT.
    function returnCircuit(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        if (!l.active) revert NotListed();
        if (l.renter == address(0)) revert NotRented();
        if (block.timestamp < l.expiresAt) revert NotExpired();

        address renter = l.renter;
        address owner_ = l.owner;
        address circuit = l.circuit;
        uint256 tokenId = l.tokenId;
        uint256 toOwner = l.escrow;

        l.active = false;
        l.renter = address(0);
        l.expiresAt = 0;
        l.escrow = 0;
        listingOfToken[circuit][tokenId] = 0;

        if (toOwner > 0) {
            (bool ok,) = payable(owner_).call{value: toOwner}("");
            require(ok, "owner payout failed");
        }
        IERC721(circuit).safeTransferFrom(address(this), owner_, tokenId);

        emit Returned(listingId, renter, toOwner);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice (renter, expiresAt, active) for a circuit — the on-chain
    ///         rental right any app can check before letting someone use it.
    function rentalOf(address circuitContract, uint256 tokenId)
        external
        view
        returns (address renter, uint256 expiresAt, bool active)
    {
        uint256 id = listingOfToken[circuitContract][tokenId];
        if (id == 0) return (address(0), 0, false);
        Listing storage l = listings[id];
        bool rented = l.renter != address(0) && block.timestamp < l.expiresAt;
        return (rented ? l.renter : address(0), rented ? l.expiresAt : 0, rented);
    }

    /// @notice True while a circuit is currently rented out (not expired).
    function isRented(address circuitContract, uint256 tokenId) external view returns (bool) {
        uint256 id = listingOfToken[circuitContract][tokenId];
        if (id == 0) return false;
        Listing storage l = listings[id];
        return l.renter != address(0) && block.timestamp < l.expiresAt;
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    // ------------------------------------------------------------------
    // Stray NFTs
    // ------------------------------------------------------------------

    /// @notice Direct ERC-721 transfers to this contract (not via list())
    ///         are NOT rentals. The contract owner can rescue such stray NFTs
    ///         to a chosen address. Listed tokens can never be rescued here
    ///         (listingOfToken != 0 blocks it).
    function rescueStray(address circuitContract, uint256 tokenId, address to) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (listingOfToken[circuitContract][tokenId] != 0) revert AlreadyListed();
        IERC721(circuitContract).safeTransferFrom(address(this), to, tokenId);
    }

    /// @dev ERC721Holder accepts safe transfers. Only list() creates a
    ///      rental; see rescueStray() for direct (non-list) transfers.
    receive() external payable {
        revert("direct OKB not accepted");
    }
}
