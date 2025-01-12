# Decentralized Bitcoin Liquidity Pool (DBLP)

A decentralized liquidity pool smart contract that enables users to deposit BTC, earn yield, and manage their liquidity positions.

## Overview

The DBLP smart contract implements a secure and efficient liquidity pool system with the following key features:

- Deposit and withdrawal mechanisms
- Yield calculation and distribution
- Administrative controls and safety measures
- Emergency pause functionality
- Comprehensive event logging

## Core Features

### Deposit Management

- Minimum deposit: 0.01 BTC (1,000,000 sats)
- Maximum deposit per user: 10 BTC (1,000,000,000 sats)
- Maximum pool size: 1000 BTC (100,000,000,000 sats)
- Automated yield calculation and accumulation

### Yield Generation

- Configurable yield rate (default: 5% APY)
- Yield calculations based on deposit amount and time
- Yield claiming mechanism for users

### Safety Measures

- Emergency pause functionality
- 24-hour cooldown period for emergency actions
- Owner-only administrative functions
- Pool activity controls

## Public Functions

### User Operations

#### `deposit`

Allows users to deposit BTC into the pool.

```clarity
(define-public (deposit (amount uint)))
```

#### `withdraw`

Enables users to withdraw their deposited BTC.

```clarity
(define-public (withdraw (amount uint)))
```

#### `claim-yield`

Allows users to claim their accumulated yield.

```clarity
(define-public (claim-yield))
```

### Read-Only Functions

#### `get-user-position`

Retrieves a user's current position details.

```clarity
(define-read-only (get-user-position (user principal)))
```

#### `get-pool-stats`

Returns current pool statistics.

```clarity
(define-read-only (get-pool-stats))
```

#### `get-event`

Retrieves specific event details.

```clarity
(define-read-only (get-event (event-id uint)))
```

### Administrative Functions

#### Pool Management

- `set-pool-active`: Enable/disable pool operations
- `emergency-pause`: Pause all pool operations
- `emergency-resume`: Resume pool operations after pause
- `set-yield-rate`: Update the yield rate
- `set-pool-parameters`: Modify pool parameters
- `add-operator`: Add authorized operators
- `remove-operator`: Remove operator access

## Error Codes

| Code | Description            |
| ---- | ---------------------- |
| 100  | Owner-only operation   |
| 101  | Resource not found     |
| 102  | Unauthorized access    |
| 103  | Insufficient balance   |
| 104  | Pool inactive          |
| 105  | Invalid amount         |
| 106  | Pool capacity exceeded |
| 107  | Invalid boolean value  |
| 108  | Cooldown period active |
| 109  | Below minimum deposit  |
| 110  | Above maximum deposit  |
| 111  | Pool paused            |
| 112  | Event logging error    |

## Events

The contract logs the following events:

- DEPOSIT
- WITHDRAW
- CLAIM
- POOL_STATUS
- EMERGENCY_PAUSE
- EMERGENCY_RESUME
- YIELD_RATE
- PARAMS_UPDATE
- ADD_OPERATOR
- REMOVE_OPERATOR

## Security Considerations

1. **Access Control**

   - Owner-only administrative functions
   - Operator authorization system
   - Emergency pause mechanism

2. **Deposit Limits**

   - Minimum deposit requirement
   - Maximum per-user deposit cap
   - Total pool size limit

3. **Safety Mechanisms**
   - Emergency pause with cooldown period
   - Yield rate limits
   - Balance validation

## Constants

- Blocks per year: 52,560 (assuming ~10 min block time)
- Emergency cooldown period: 144 blocks (24 hours)
- Basis points denominator: 10,000

## State Management

The contract maintains state through:

- Total liquidity tracking
- User deposit records
- Yield snapshots
- Event logging
- Pool status flags
