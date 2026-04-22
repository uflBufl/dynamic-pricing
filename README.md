# Dynamic Pricing Proxy

## Overview

Dynamic Pricing Proxy — an intermediate Ruby on Rails service between clients and the external pricing model.

## Problem

- **Rate-api constraint**: The external pricing model allows only 1,000 calls per day with a single API token
- **Throughput requirement**: Need to serve at least 10,000 requests per day from clients
- **Rate validity**: Each rate is valid for only 5 minutes

## Solution

The solution implements a hybrid caching strategy:

1. **Batch Refresh** — A background job (`PricingCacheUpdaterJob`) runs every 4 minutes, fetches all 36 possible combinations in a single API call, and stores rates in SolidCache with 5-minute TTL

2. **Lazy Loading** — On cache miss, individual fetch triggers to minimize user latency

## Architecture

### Request Flow

1. Client sends GET /api/v1/pricing with parameters (period, hotel, room)
2. PricingController validates the parameters
3. PricingService checks SolidCache for existing rate
4. On cache hit — return rate immediately
5. On cache miss — call RateApiClient for single combination, store in cache

### Background Job Flow

1. PricingCacheUpdaterJob runs every 4 minutes via SolidQueue
2. Fetches all 36 possible combinations (4 periods × 3 hotels × 3 rooms) in one API call
3. Stores each rate in SolidCache with 5-minute TTL

### Components

| Component | Purpose |
|-----------|---------|
| PricingController | HTTP endpoint, validates query params |
| PricingService | Business logic, reads/writes cache |
| RateApiClient | HTTP client wrapper for rate-api |
| PricingCacheUpdaterJob | Scheduled batch refresh job |

### Dependencies

| Gem        | Purpose |
|------------|--------|
| HTTParty   | HTTP client for rate-api |
| SolidCache | SQLite-backed cache |
| SolidQueue | Job queue + recurring tasks |
| SQLite3   | Database |

## Design Decisions

### Why batch refresh instead of pure lazy loading?

**Pure lazy loading** (fetch on miss) is simple but risky:
- Worst case: 36 different cache misses every 5 minutes = 10,368 API calls/day
- This exceeds the 1,000 call/day limit by 10x

**Batch refresh** mitigates this by pre-fetching all combinations in a single API call:
- 15 times/hour × 24 hours = 360 API calls/day
- Well under the 1,000 limit with buffer for retries

### Why every 4 minutes?

- Provides buffer before 5-minute TTL expiration for mitigation possible retry attempts and "computationally expensive" request

### Why SolidCache instead of Redis?

**In-memory cache (Redis)** requires all data stored in RAM:
- Expensive at scale — memory costs add up
- Data loss on crash/restart — Redis flushes on failure

**Disk-based cache (SolidCache with SQLite):**
- Lower cost — uses disk storage, not RAM
- Data persists across restarts — no data loss
- Simpler setup — single gem, no external service
