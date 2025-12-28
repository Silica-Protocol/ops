# SDK Consistency Guide

This document defines the API surface and consistency requirements for all Silica Protocol SDKs.

## Overview

Silica Protocol maintains official SDKs in five languages:
- **Rust** (`sdk-rust`) - Primary, reference implementation
- **TypeScript** (`sdk-typescript`) - Web and Node.js
- **Python** (`sdk-python`) - Data science and scripting
- **Go** (`sdk-go`) - Server-side and infrastructure
- **C#** (`sdk-csharp`) - .NET ecosystem

## Consistency Principles

### 1. Feature Parity

All SDKs MUST implement the same core functionality:

| Feature | Rust | TypeScript | Python | Go | C# |
|---------|------|------------|--------|----|----|
| Connect/Disconnect | ✓ | ✓ | ✓ | ✓ | ✓ |
| Query Balance | ✓ | ✓ | ✓ | ✓ | ✓ |
| Send Transaction | ✓ | ✓ | ✓ | ✓ | ✓ |
| Transaction Status | ✓ | ✓ | ✓ | ✓ | ✓ |
| Block Queries | ✓ | ✓ | ✓ | ✓ | ✓ |
| Subscription/Events | ✓ | ✓ | ✓ | ✓ | ✓ |
| Wallet Management | ✓ | ✓ | ✓ | ✓ | ✓ |
| Contract Interaction | ✓ | ✓ | ✓ | ✓ | ✓ |

### 2. Naming Conventions

Each language follows its idiomatic conventions:

| Concept | Rust | TypeScript | Python | Go | C# |
|---------|------|------------|--------|----|----|
| Function | `get_balance` | `getBalance` | `get_balance` | `GetBalance` | `GetBalance` |
| Type | `BlockHeader` | `BlockHeader` | `BlockHeader` | `BlockHeader` | `BlockHeader` |
| Constant | `MAX_GAS` | `MAX_GAS` | `MAX_GAS` | `MaxGas` | `MaxGas` |

### 3. Version Synchronization

All SDKs MUST be released with the same version number:

```
v0.1.0 - All SDKs release together
v0.1.1 - All SDKs release together
v0.2.0 - All SDKs release together
```

Version is tracked in `ops/config/versions.toml`:

```toml
[sdks]
rust = "0.1.0"
typescript = "0.1.0"
python = "0.1.0"
go = "0.1.0"
csharp = "0.1.0"
```

## Core API Specification

### Client Interface

Every SDK must implement a client with these capabilities:

```typescript
// TypeScript reference (adapt to each language's idioms)

interface SilicaClient {
  // Connection
  connect(endpoint: string, options?: ConnectOptions): Promise<void>;
  disconnect(): Promise<void>;
  isConnected(): boolean;

  // Account
  getBalance(address: string): Promise<Balance>;
  getAccountInfo(address: string): Promise<AccountInfo>;
  getNonce(address: string): Promise<number>;

  // Transactions
  sendTransaction(tx: SignedTransaction): Promise<TxHash>;
  getTransaction(hash: TxHash): Promise<Transaction | null>;
  getTransactionReceipt(hash: TxHash): Promise<TxReceipt | null>;
  estimateGas(tx: UnsignedTransaction): Promise<GasEstimate>;

  // Blocks
  getLatestBlock(): Promise<Block>;
  getBlock(heightOrHash: number | string): Promise<Block | null>;
  getBlockByHash(hash: string): Promise<Block | null>;
  getBlockByNumber(height: number): Promise<Block | null>;

  // Subscriptions
  subscribeNewBlocks(callback: (block: Block) => void): Subscription;
  subscribeTransactions(callback: (tx: Transaction) => void): Subscription;
  subscribeLogs(filter: LogFilter, callback: (log: Log) => void): Subscription;

  // Contracts
  callContract(call: ContractCall): Promise<ContractResult>;
  deployContract(code: Uint8Array, args: any[]): Promise<TxHash>;
}
```

### Wallet Interface

```typescript
interface Wallet {
  // Key Management
  create(): Wallet;
  fromMnemonic(mnemonic: string): Wallet;
  fromPrivateKey(key: Uint8Array): Wallet;
  
  // Properties
  getAddress(): string;
  getPublicKey(): Uint8Array;
  
  // Signing
  sign(message: Uint8Array): Signature;
  signTransaction(tx: UnsignedTransaction): SignedTransaction;
  
  // Encryption (for storage)
  encrypt(password: string): EncryptedWallet;
  static decrypt(encrypted: EncryptedWallet, password: string): Wallet;
}
```

### Type Definitions

All SDKs must use consistent type structures:

```typescript
// Core Types (adapt serialization to each language)

interface Transaction {
  hash: string;           // 32 bytes hex
  from: string;           // Address
  to: string | null;      // Address or null for contract deploy
  value: bigint;          // Amount in smallest unit
  gasLimit: bigint;
  gasPrice: bigint;
  nonce: number;
  data: Uint8Array;
  signature: Signature;
  timestamp: number;      // Unix timestamp
}

interface Block {
  hash: string;           // 32 bytes hex
  parentHash: string;
  height: number;
  timestamp: number;
  proposer: string;       // Validator address
  transactions: string[]; // Transaction hashes
  stateRoot: string;
  receiptsRoot: string;
}

interface Balance {
  available: bigint;
  staked: bigint;
  locked: bigint;
  total: bigint;
}
```

## Error Handling

### Error Types

All SDKs must define these error categories:

```typescript
enum ErrorCode {
  // Connection
  CONNECTION_FAILED = "CONNECTION_FAILED",
  CONNECTION_TIMEOUT = "CONNECTION_TIMEOUT",
  DISCONNECTED = "DISCONNECTED",
  
  // Transaction
  INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE",
  INVALID_NONCE = "INVALID_NONCE",
  GAS_LIMIT_EXCEEDED = "GAS_LIMIT_EXCEEDED",
  TX_REJECTED = "TX_REJECTED",
  
  // Query
  NOT_FOUND = "NOT_FOUND",
  INVALID_ADDRESS = "INVALID_ADDRESS",
  INVALID_HASH = "INVALID_HASH",
  
  // Crypto
  INVALID_SIGNATURE = "INVALID_SIGNATURE",
  INVALID_KEY = "INVALID_KEY",
  
  // Internal
  INTERNAL_ERROR = "INTERNAL_ERROR",
  UNSUPPORTED = "UNSUPPORTED",
}
```

### Error Structure

```typescript
interface SilicaError {
  code: ErrorCode;
  message: string;
  details?: Record<string, any>;
  cause?: Error;
}
```

## Testing Requirements

Each SDK must have:

### Unit Tests
- [ ] All public methods covered
- [ ] Error cases tested
- [ ] Edge cases (empty, null, max values)

### Integration Tests
- [ ] Connect to testnet
- [ ] Submit and query transactions
- [ ] Block subscriptions
- [ ] Contract deployment and calls

### Compatibility Tests
- [ ] Cross-SDK transaction signing verification
- [ ] Serialization/deserialization round-trips
- [ ] Address format validation

## Documentation Requirements

Each SDK must include:

1. **README.md** - Quick start and installation
2. **API Reference** - Generated from code comments
3. **Examples** - Common use cases
4. **Migration Guide** - For breaking changes

## Release Process

### Pre-Release Checklist

- [ ] Version bumped in all SDKs
- [ ] CHANGELOG updated
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Cross-SDK compatibility verified
- [ ] Security audit (for major releases)

### Release Order

1. `sdk-rust` (reference implementation)
2. `sdk-typescript` 
3. `sdk-python`
4. `sdk-go`
5. `sdk-csharp`

### Publishing Targets

| SDK | Registry | Package Name |
|-----|----------|--------------|
| Rust | crates.io | `chert-sdk` |
| TypeScript | npm | `@silica-protocol/sdk` |
| Python | PyPI | `chert-sdk` |
| Go | go modules | `github.com/Silica-Protocol/sdk-go` |
| C# | NuGet | `Silica.Sdk` |

## Validation Script

Run consistency checks:

```bash
cd ops
./scripts/validate-sdks.sh
```

This verifies:
- Required methods exist
- Version consistency
- Package configurations
- Test coverage thresholds
