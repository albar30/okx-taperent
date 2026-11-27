// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockCircuit — DEMO-ONLY stand-in for a TapeOut circuit contract
/// @notice This is NOT a real TapeOut circuit. X Layer testnet (Terigon,
///         chain 1952) has NO TapeOut factory deployed, so this mock lets the
///         TapeRent frontend and tests exercise the full list/rent/return
///         flow on testnet. It mimics the real circuit interface that
///         TapeRent relies on: ERC-721 (ownerOf/transferFrom/
///         safeTransferFrom) plus circuitInfo / nextId / TAPEOUT_FEE.
///         On X Layer mainnet (chain 196) use the REAL TapeOut circuits,
///         e.g. CPU #0 "OnlyTestXLayer" 0x839bdd6fa7a66416a609a735e11de5411b98574e.
contract MockCircuit is ERC721 {
    uint256 public constant TAPEOUT_FEE = 0.005214 ether;

    uint256 public nextId = 1;

    struct CircuitInfo {
        uint32 nIn;
        uint32 nOut;
        uint32 nState;
        uint256 gateCount;
    }

    mapping(uint256 => CircuitInfo) private _infos;
    mapping(uint256 => bytes) private _netlists;

    event Tapeout(uint256 indexed id, address indexed to, uint32 nIn, uint32 nOut);

    constructor() ERC721("MockCircuit (DEMO ONLY)", "MOCK") {}

    /// @notice Mint a mock circuit, mimicking TapeOut's tapeout() shape.
    ///         Charges the same nominal fee as the real CPU #0 fee read on
    ///         25 Nov 2026 (0.005214 OKB) — testnet OKB only, no real value.
    function tapeout(bytes calldata netlistBytes, uint32 nIn, uint32 nOut) external payable returns (uint256 id) {
        require(msg.value == TAPEOUT_FEE, "exact TAPEOUT_FEE required");
        id = nextId++;
        _infos[id] = CircuitInfo({nIn: nIn, nOut: nOut, nState: 0, gateCount: netlistBytes.length});
        _netlists[id] = netlistBytes;
        _safeMint(msg.sender, id);
        emit Tapeout(id, msg.sender, nIn, nOut);
    }

    /// @notice Free mint helper for demos (no fee) — clearly a mock-only path.
    function mintDemo(uint32 nIn, uint32 nOut) external returns (uint256 id) {
        id = nextId++;
        _infos[id] = CircuitInfo({nIn: nIn, nOut: nOut, nState: 0, gateCount: 4});
        _safeMint(msg.sender, id);
        emit Tapeout(id, msg.sender, nIn, nOut);
    }

    function circuitInfo(uint256 id)
        external
        view
        returns (uint32 nIn, uint32 nOut, uint32 nState, uint256 gateCount)
    {
        CircuitInfo storage c = _infos[id];
        return (c.nIn, c.nOut, c.nState, c.gateCount);
    }

    function netlist(uint256 id) external view returns (bytes memory) {
        return _netlists[id];
    }

    /// @notice Withdraw accumulated mock tapeout fees (testnet only).
    function withdrawFees(address to) external {
        payable(to).transfer(address(this).balance);
    }
}
