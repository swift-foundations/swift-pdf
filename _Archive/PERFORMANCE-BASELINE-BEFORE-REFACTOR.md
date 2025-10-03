# Performance Baseline - Before Intelligent Concurrency Refactor

**Date:** 2025-10-02
**System:** macOS Version 26.0, 8 CPU Cores, 24 GB RAM
**Swift Version:** 6.0+
**Current Concurrency:** `min(ProcessInfo.processInfo.activeProcessorCount, 8)` = **8 concurrent operations**

---

## Performance Results - Paginated Mode (Print-Ready)

Paginated mode uses NSPrintOperation for proper multi-page documents (invoices, reports).

| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |
|---------------------------|----------|----------|--------------|-----------|----------|
| 100 Simple                | 100      | 0.68    s | 148          | 6.76      ms | 102.9   MB |
| 1,000 Simple              | 1000     | 1.45    s | 689          | 1.45      ms | 110.2   MB |
| 10,000 Simple             | 10000    | 20.79   s | 481          | 2.08      ms | 136.6   MB |
| 100 Complex               | 100      | 0.41    s | 245          | 4.09      ms | 142.0   MB |
| 1,000 Complex             | 1000     | 3.96    s | 253          | 3.96      ms | 146.5   MB |

## Performance Results - Continuous Mode (Fast)

Continuous mode uses WKWebView.createPDF for single-page documents (web captures, articles).

| Test                      | Count    | Duration | Throughput   | Avg/PDF   | Peak Mem |
|---------------------------|----------|----------|--------------|-----------|----------|
| 100 Simple                | 100      | 0.05    s | 1822         | 0.55      ms | 147.0   MB |
| 1,000 Simple              | 1000     | 0.51    s | 1946         | 0.51      ms | 147.2   MB |
| 10,000 Simple             | 10000    | 5.29    s | 1890         | 0.53      ms | 149.0   MB |

## Detailed Performance Metrics

| Test                      | Count    | Duration | Throughput   | Avg      | p50      | p95      | p99      | Peak Mem |
|---------------------------|----------|----------|--------------|----------|----------|----------|----------|----------|
| 100 Simple                | 100      | 0.05    s | 1822         | 0.55    ms | 3.68    ms | 6.95    ms | 7.12    ms | 147.0   MB |
| 1,000 Simple              | 1000     | 0.51    s | 1946         | 0.51    ms | 3.66    ms | 4.82    ms | 5.44    ms | 147.2   MB |
| 10,000 Simple             | 10000    | 5.29    s | 1890         | 0.53    ms | 3.74    ms | 4.94    ms | 5.82    ms | 149.0   MB |
| 100 Simple                | 100      | 0.68    s | 148          | 6.76    ms | 11.94   ms | 534.14  ms | 534.57  ms | 102.9   MB |
| 1,000 Simple              | 1000     | 1.45    s | 689          | 1.45    ms | 11.05   ms | 12.96   ms | 14.05   ms | 110.2   MB |
| 10,000 Simple             | 10000    | 20.79   s | 481          | 2.08    ms | 15.46   ms | 23.08   ms | 24.27   ms | 136.6   MB |
| 100 Complex               | 100      | 0.41    s | 245          | 4.09    ms | 22.93   ms | 33.31   ms | 38.03   ms | 142.0   MB |
| 1,000 Complex             | 1000     | 3.96    s | 253          | 3.96    ms | 23.37   ms | 27.21   ms | 34.08   ms | 146.5   MB |

## Key Metrics to Compare After Refactor

**Throughput (PDFs/sec):**
- Continuous mode: **1,946 PDFs/sec** (best case)
- Paginated mode: **689 PDFs/sec** (best case)

**Memory:**
- Continuous mode average: **147.7 MB**
- Paginated mode average: **127.6 MB**

**Expected Impact of Refactor:**
- On this 8-core system: **Minimal change** (already using 8 cores)
- On 16+ core systems: **50-100% throughput improvement** expected
- Memory: Should remain similar (memory-based cap will prevent increase)

## Pool Configuration (Current)

```swift
let cpuCount = ProcessInfo.processInfo.activeProcessorCount  // = 8
poolSize = max(2, min(cpuCount, 8))  // = 8
```

**Hardcoded cap at 8** - this is what we're removing.

---

After implementing the refactor, run the same benchmark and compare:
```bash
swift test --filter generateReadmeTable
```
