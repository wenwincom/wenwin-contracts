# Wenwin contracts

Wenwin is a decentralized gaming protocol that provides developers with the ability to create chance-based games on the
blockchain. This repository contains the smart contracts for Wenwin.

## Development

### Installation

To get started with developing the Wenwin contracts, you'll need to
[install Foundry](https://book.getfoundry.sh/getting-started/installation). After cloning the repository with its
submodules, the development environment will be ready.

### Building

The project can be built using the following command in the terminal:

```Shell
forge build
```

### Testing

To run the unit tests, use the following command:

```bash
forge test
```

Additionally, to view the code coverage, run the command in the terminal:

```bash
bash script/sh/generateCoverageReport.sh
```

This will generate a detailed HTML report of the code coverage.

### Slither

Slither is a useful tool for analyzing Solidity code for security issues and other code quality concerns
([installation instructions](https://book.getfoundry.sh/config/static-analyzers#slither)). To run Slither, execute the
following command in the terminal:

```bash
slither .
```

## Lottery

The Wenwin Lottery is a next-generation lottery game built on Polygon that utilizes blockchain technology to provide a
new level of transparency, security, convenience, and efficiency.

To read more about the game, visit the [Wenwin Lottery docs](https://docs.wenwin.com/wenwin-lottery).

### Rules

The Wenwin Lottery is a `selectionSize`/`selectionMax` lottery where users can buy unlimited tickets for each draw. The
draws occur periodically, and the [prizes](https://docs.wenwin.com/wenwin-lottery/the-game/prizes) are distributed among
the winners.

#### Selection

Lottery operates with two parameters for the selection of numbers for the ticket:

- `selectionSize`: Defines the size of the selection that a user chooses when registering the ticket. The maximum value
  is 16.
- `selectionMax`: Defines the maximum number that can be selected. The range for selection is between 1 and
  selectionMax. The maximum value is 120.

#### Period

A lottery draw occurs periodically, and deadlines are defined with these parameters:

- `firstDrawSchedule`: The timestamp of the first draw that will occur after deployment of the lottery.
- `drawPeriod`: The period of draws. Each draw is scheduled at `firstDrawSchedule + drawId * drawPeriod`.
- `drawCooldownPeriod`: The period that occurs just before the draw when tickets cannot be bought.

The execution of a draw is not automatic since someone needs to trigger it by calling the `executeDraw` method from
`Lottery.sol` after the scheduled time passed.

#### Pot size

The pot can be increased by:

1. Buying tickets
2. Topping up (adding funds to the pot without buying tickets)
3. Pot rollover (if there was no win for the jackpot, the funds are rolled over to the next draw).

#### Draw

A draw is finalized by generating a random number from [ChainLink VRFv2](https://chain.link/vrf). After the random
number is received, it constructs the winning ticket. All users that have the winning ticket split the pot. Users that
have won can claim winnings from the contract by calling the `claimWinningTickets` method from `Lottery.sol` with the
winning tickets.

#### Rewards

Each ticket sale generates rewards for stakers and frontend operators. The rewards can be claimed by calling the
`claimRewards` method from `Lottery.sol`.

To read more about the rewards, visit the
[staking](https://docs.wenwin.com/wenwin-lottery/protocol-architecture/token/staking) and
[frontend operator](https://docs.wenwin.com/wenwin-lottery/protocol-architecture/frontend-operators) docs.

### Tickets

Purchasing a ticket is the only way to participate in the lottery. Each ticket is an NFT that must be delivered in order
to claim any prizes.

To read more about the tickets, visit the [tickets docs](https://docs.wenwin.com/wenwin-lottery/the-game/tickets).

#### Representation

A ticket is represented as a single `uint120`. Each bit in the range [0, `selectionMax`) represents whether a particular
number is selected for the ticket (`i`th bit represents `i+1`th number selected). To be a valid ticket, exactly
`selectionSize` bits need to be set to `1`.

For example, a ticket with numbers `[4, 7, 11, 13, 20, 25, 30]` is represented as
`0b00000100001000010000001010001001000` for the 7/35 lottery.

#### Buying a ticket

Tickets are bought by calling a method `buyTickets` from `Lottery.sol`.
