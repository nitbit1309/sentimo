# Sentimo

Sentimo is a blockchain based play to earn game. The game features various polls created by the community users. Players provide their response in polls by participating in it. Players also bet by a guessing a percentage number to a question about how many participants have selected a perticular option. If players guess the correct percentage then they will win the poll and get the reward otherwise they will loose their bet.

## Basic economy principles:

- A creator of the poll should be incentivized so that creators gets motivated to create more polls and invite players.
- Creator's earning should be linked to no of players in the poll
- There should be a factor of loss for creator as well.
- Players should get a good bet/reward ratio.

## Design principles

- A concept of base reward and fee for players is introduced. The creator need to provide a base reward for the poll. The creator also specifies the fee associated with the poll for players to participate.
  The reward for creator is linked to the base reward, player fee and no of players in a poll. If `player_fee*player_count > base_reward` then creator will get the base reward return to him. The creator will also get 20% of the difference between base reward and poll fee collection.
  If `player_fee*player_count < base_reward` then creator will loose the entire base reward

  This will motivate creator to create more polls and invite players to the poll.

- Players will choose the poll to participate based on the poll fee and base/poll reward.
- Since the bets needs to be private until the timer expires, Hidden/Reveal user data pattern is used.

## Future improvements

- An additional mount may be taken at the time of voting which will get refunded at the time of revealing so that players must reveal their poll response, Otherwise players will wait for other players to reveal their vote and calcuate if they want to reveal their vote.

- 10% of total players should be rewarded as it will increase the participation
- Fraction/decimal numbers can be used to guess the overall percentage. It will make this game more difficult.
- An ERC20 token can be introduced to provide aditional rewards. This needs to be implemented cautiosly as players/poll creators can abuse the system.
- Players should be able to participate using USDC or other tokens
