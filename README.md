# Scallop Referral Program

A smart contract on Sui blockchain that implements a referral system for Scallop Protocol, enabling users to earn rewards through referrals based on their veSCA (vote-escrowed SCA) holdings.

## Overview

The Scallop Referral Program incentivizes users to refer others to the Scallop lending protocol. Referrers with veSCA holdings can share their referral link, and when referred users (referees) borrow through the protocol, both parties benefit:

- **Referees** receive a discount on borrow fees
- **Referrers** earn a share of the borrow fees as revenue

The reward rates are determined by tier levels based on the referrer's veSCA amount.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Scallop Referral Program                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │ ReferralBindings│    │  ReferralTiers  │    │ RevenuePool │ │
│  │                 │    │                 │    │             │ │
│  │ referee → veSCA │    │ veSCA amount →  │    │ veSCA ID →  │ │
│  │    mapping      │    │ (share, discount)│   │   rewards   │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │     Admin       │    │    Version      │                    │
│  │                 │    │                 │                    │
│  │ Tier management │    │ Contract version│                    │
│  └─────────────────┘    └─────────────────┘                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

### `scallop_referral_program`

The main module that handles the referral ticket lifecycle:

- `claim_ve_sca_referral_ticket`: Creates a referral ticket for borrowing with discounted fees
- `burn_ve_sca_referral_ticket`: Burns the ticket after borrowing and distributes revenue to the referrer

### `referral_bindings`

Manages the mapping between referees and referrers:

- `bind_ve_sca_referrer`: Binds a referee address to a referrer's veSCA
- `unbind_ve_sca_referrer`: Removes the binding between a referee and their referrer
- `get_binding`: Retrieves the current binding for an address

### `referral_tiers`

Defines reward tiers based on veSCA holdings:

- `add_tier`: Adds a new tier (admin only)
- `remove_tier`: Removes an existing tier (admin only)
- `find_tier`: Finds the applicable tier for a given veSCA amount

### `referral_revenue_pool`

Manages the revenue distribution:

- `claim_revenue_with_ve_sca_key`: Allows referrers to claim accumulated rewards
- `add_revenue_to_ve_sca_referrer`: Internal function to add revenue for a referrer

### `admin`

Administrative functions:

- `add_referral_tier`: Add new tier configuration
- `remove_referral_tier`: Remove tier configuration
- `set_contract_version`: Update contract version after upgrades

## Usage

### For Referees (Borrowers)

1. **Bind to a referrer**
   ```move
   referral_bindings::bind_ve_sca_referrer(
       referral_bindings,
       ve_sca_key_id,      // Referrer's veSCA key ID
       ve_sca_table,
       clock,
       ctx
   );
   ```

2. **Borrow with referral discount**
   ```move
   // Claim referral ticket
   let ticket = scallop_referral_program::claim_ve_sca_referral_ticket<CoinType>(
       version,
       ve_sca_table,
       referral_bindings,
       authorized_witness_list,
       referral_tiers,
       clock,
       ctx
   );

   // Use ticket with Scallop borrow function
   // ...

   // Burn ticket after borrowing
   scallop_referral_program::burn_ve_sca_referral_ticket<CoinType>(
       version,
       ticket,
       referral_revenue_pool,
       clock,
       ctx
   );
   ```

3. **Unbind from referrer** (optional)
   ```move
   referral_bindings::unbind_ve_sca_referrer(
       referral_bindings,
       ctx
   );
   ```

### For Referrers

1. **Share your veSCA key ID** with potential referees

2. **Claim accumulated rewards**
   ```move
   let reward = referral_revenue_pool::claim_revenue_with_ve_sca_key<CoinType>(
       version,
       referral_revenue_pool,
       ve_sca_key,
       clock,
       ctx
   );
   ```

## Deployment

### Prerequisites

- [Sui CLI](https://docs.sui.io/build/install)
- Node.js >= 16

### Build

```bash
sui move build
```

### Test

```bash
sui move test
```

### Publish

```bash
sui client publish --gas-budget 100000000
```

## Contract Addresses

### Mainnet

- Package: `0x5658d4bf5ddcba27e4337b4262108b3ad1716643cac8c2054ac341538adc72ec`

## Dependencies

- [Sui Framework](https://github.com/MystenLabs/sui)
- [Scallop Protocol](https://github.com/scallop-io/sui-lending-protocol)
- [VeSCA](https://github.com/scallop-io/ve-sca-interface)

## Security

This contract implements several security measures:

- Version control to ensure compatibility after upgrades
- Admin capability pattern for privileged operations
- Validation of veSCA ownership before binding

## License

This project is proprietary software owned by Scallop Labs.
