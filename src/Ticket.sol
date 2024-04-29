// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "src/interfaces/ITicket.sol";

/// @dev Ticket ownership is represented as NFT. Whoever owns NFT is the owner of particular ticket in Lottery.
/// If it represents a winning ticket, it can be used to claim a reward from Lottery.
/// Ticket can change ownership before or after ticket has been claimed.
/// Since mint is internal, only derived contracts can mint tickets.
abstract contract Ticket is ITicket, ERC721, Ownable2Step {
    uint256 public override nextTicketId;
    mapping(uint256 => ITicket.TicketInfo) public override ticketsInfo;

    string private _baseTokenURI;

    // solhint-disable-next-line no-empty-blocks
    constructor(string memory baseURI) ERC721("Wenwin Lottery Ticket", "WLT") {
        _baseTokenURI = baseURI;
    }

    function mint(address to, uint128 drawId, uint120 combination) internal returns (uint256 ticketId) {
        ticketId = nextTicketId++;
        ticketsInfo[ticketId] = TicketInfo(drawId, combination);
        _mint(to, ticketId);
    }

    function setBaseURI(string memory newBaseTokenURI) external override onlyOwner {
        _baseTokenURI = newBaseTokenURI;
    }

    function _baseURI() internal view override returns (string memory baseURI) {
        baseURI = _baseTokenURI;
    }
}
