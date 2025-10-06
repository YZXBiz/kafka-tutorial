# 13. Monitoring Kafka

> **In plain English:** Monitoring Kafka is like having a comprehensive health dashboard for your car - you need to know not just if it's running, but how fast, how efficiently, and what might break soon.
>
> **In technical terms:** Kafka monitoring involves collecting, analyzing, and alerting on metrics from brokers, clients, and infrastructure to ensure reliable message delivery and optimal performance.
>
> **Why it matters:** Without proper monitoring, you're flying blind. A small disk failure on one broker can cascade into cluster-wide outages. Good monitoring catches problems before customers notice them.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Metric Basics](#2-metric-basics)
   - 2.1. [Where Are the Metrics?](#21-where-are-the-metrics)
   - 2.2. [Nonapplication Metrics](#22-nonapplication-metrics)
   - 2.3. [What Metrics Do I Need?](#23-what-metrics-do-i-need)
   - 2.4. [Application Health Checks](#24-application-health-checks)
3. [Service-Level Objectives](#3-service-level-objectives)
   - 3.1. [Service-Level Definitions](#31-service-level-definitions)
   - 3.2. [What Metrics Make Good SLIs?](#32-what-metrics-make-good-slis)
   - 3.3. [Using SLOs in Alerting](#33-using-slos-in-alerting)
4. [Kafka Broker Metrics](#4-kafka-broker-metrics)
   - 4.1. [Diagnosing Cluster Problems](#41-diagnosing-cluster-problems)
   - 4.2. [The Art of Under-Replicated Partitions](#42-the-art-of-under-replicated-partitions)
   - 4.3. [Cluster-Level Problems](#43-cluster-level-problems)
   - 4.4. [Host-Level Problems](#44-host-level-problems)
   - 4.5. [Broker Metrics](#45-broker-metrics)
   - 4.6. [Request Metrics](#46-request-metrics)
   - 4.7. [Topic and Partition Metrics](#47-topic-and-partition-metrics)
5. [JVM Monitoring](#5-jvm-monitoring)
   - 5.1. [Garbage Collection](#51-garbage-collection)
   - 5.2. [Java OS Monitoring](#52-java-os-monitoring)
6. [OS Monitoring](#6-os-monitoring)
7. [Logging](#7-logging)
8. [Client Monitoring](#8-client-monitoring)
   - 8.1. [Producer Metrics](#81-producer-metrics)
   - 8.2. [Consumer Metrics](#82-consumer-metrics)
   - 8.3. [Quotas](#83-quotas)
9. [Lag Monitoring](#9-lag-monitoring)
10. [End-to-End Monitoring](#10-end-to-end-monitoring)
11. [Summary](#11-summary)

---

## 1. Introduction

Apache Kafka applications provide numerous measurements for their operation—so many, in fact, that it can easily become overwhelming. Metrics range from simple overall traffic rates to detailed timing for every request type to per-topic and per-partition measurements.

**In plain English:** Kafka gives you thousands of metrics. It's like a modern car with sensors for everything—oil pressure, tire pressure, fuel efficiency, engine temperature, and hundreds more. The challenge isn't getting data; it's knowing which metrics actually matter.

> **💡 Insight**
>
> The most common mistake in monitoring is collecting everything and alerting on nothing useful. Good monitoring follows the 80/20 rule: 20% of metrics identify 80% of problems. Start with critical metrics and expand gradually.

This chapter details:
- **Critical metrics** to monitor continuously
- **Debugging metrics** to have available when needed
- **Best practices** for alerting and response

**Note:** This is not an exhaustive list. Kafka metrics change frequently, and many are only useful to core Kafka developers.

---

## 2. Metric Basics

Before diving into specific Kafka metrics, let's establish monitoring fundamentals applicable to all Java applications.

### 2.1. Where Are the Metrics?

All Kafka metrics are accessible via **Java Management Extensions (JMX)**.

**In plain English:** JMX is like a standardized dashboard interface for Java applications—it exposes internal measurements in a consistent format that monitoring tools can read.

#### Collection Methods

**Option 1: External JMX Agent**
```
Monitoring System → JMX Agent → Connects to Kafka JMX Port → Reads Metrics
```
Examples: Nagios XI check_jmx, jmxtrans

**Option 2: In-Process HTTP Agent**
```
Monitoring System → HTTP Request → Agent in Kafka Process → Returns Metrics
```
Examples: Jolokia, MX4J

**Option 3: Monitoring as a Service**
```
Your Kafka → Cloud Agent → Cloud Platform → Dashboards + Alerts
```
Examples: Datadog, New Relic, Prometheus

> **💡 Insight**
>
> Remote JMX is disabled by default in Kafka for security reasons. JMX allows not just monitoring but code execution. Always use an in-process agent or secure remote JMX with authentication and encryption.

#### Finding the JMX Port

The broker stores its JMX port in ZooKeeper at `/brokers/ids/<ID>`:

```json
{
  "hostname": "kafka1.example.com",
  "jmx_port": 9999,
  "port": 9092
}
```

**Security warning:** Only enable remote JMX with proper security configuration.

### 2.2. Nonapplication Metrics

Not all metrics come from Kafka itself. Five metric categories exist:

#### Metric Source Categories

```
Application Metrics (Kafka JMX)
        ↓
    Logs (Kafka log files)
        ↓
Infrastructure Metrics (Load balancers, proxies)
        ↓
Synthetic Clients (External monitors like Kafka Monitor)
        ↓
Client Metrics (Producer/Consumer JMX)
```

**Metric Source Details:**

| Category | Description | Objectivity |
|----------|-------------|-------------|
| Application metrics | Kafka's own JMX metrics | Subjective (Kafka's view) |
| Logs | Text/structured log data | Subjective |
| Infrastructure metrics | Load balancers, network devices | Somewhat objective |
| Synthetic clients | External monitoring tools | Objective |
| Client metrics | Producer/consumer metrics | Most objective |

**In plain English:** Think of a website health check. The web server says "I'm running fine" (application metrics), but users can't connect due to a network issue. Only an external check (synthetic client) catches this.

> **💡 Insight**
>
> Objectivity increases as you move down the list. Early in your Kafka journey, broker metrics suffice. As you mature, external synthetic monitoring becomes critical for truly objective health assessment.

### 2.3. What Metrics Do I Need?

The answer depends on several factors:

#### Alerting vs. Debugging

**Alerting Metrics:**
- Short retention period (hours to days)
- Objective measurements preferred
- Automated responses
- Focus on customer impact

**Debugging Metrics:**
- Long retention period (weeks to months)
- Subjective measurements acceptable
- Human analysis
- Detailed technical information

**In plain English:** Alerting metrics are like smoke detectors—they tell you there's a problem right now. Debugging metrics are like security camera footage—you review them after an incident to understand what happened.

#### Historical Metrics

**Purpose:** Capacity planning and trend analysis

**Characteristics:**
- Very long retention (years)
- Resource usage focus (CPU, disk, network)
- Metadata context (cluster changes, broker additions)

#### Automation vs. Humans

**For Automation:**
- Many specific metrics are fine
- Precise thresholds
- Minimal interpretation needed
- Computer-friendly formats

**For Humans:**
- Fewer, high-level metrics
- Avoid alert fatigue
- Clear severity indicators
- Human-friendly summaries

**Car dashboard analogy:**
```
Computer Needs:           Human Needs:
─────────────            ────────────
Air density              Check Engine Light
Fuel pressure            Fuel Gauge
Exhaust temp             Oil Light
O2 sensor readings       Speedometer
Throttle position        Temperature Gauge
(100+ sensors)           (5-10 indicators)
```

> **💡 Insight**
>
> Alert fatigue destroys trust in monitoring systems. When every metric generates alerts, operators learn to ignore them. Better: one "Check Engine" light that triggers deep investigation.

### 2.4. Application Health Checks

Always monitor overall application health via:

**Method 1: External Process Check**
- Connects to Kafka's client port (9092)
- Verifies broker responds
- Independent of Kafka's self-reporting

**Method 2: Stale Metrics Detection**
- Alert when metrics stop updating
- Challenge: Can't distinguish Kafka failure from monitoring failure

**In plain English:** Method 1 is like knocking on a door to see if anyone answers. Method 2 is like noticing the mail hasn't been picked up—something's wrong, but you don't know what.

**Best practice:** Use Method 1 (external health check) for clarity.

---

## 3. Service-Level Objectives

**In plain English:** SLOs are promises about service quality—like a restaurant promising your meal in 30 minutes or it's free.

### 3.1. Service-Level Definitions

#### Service-Level Indicator (SLI)

**Definition:** A metric describing one aspect of reliability

**Example:** Proportion of requests returning in under 10ms

**Formula:**
```
SLI = (good events) / (total events)
    = (requests < 10ms) / (all requests)
    = 995,000 / 1,000,000
    = 99.5%
```

#### Service-Level Objective (SLO)

**Definition:** SLI + target value + timeframe

**Example:** "99.9% of requests must respond within 10ms over 7 days"

**Components breakdown:**
- **SLI:** Request response time
- **Target:** 99.9% (three nines)
- **Threshold:** 10ms
- **Timeframe:** 7 days

#### Service-Level Agreement (SLA)

**Definition:** Contract with penalties

**Example SLA:**
```
SLO: 99.9% of requests < 10ms over 7 days

If SLO is breached:
- Refund 100% of fees for breach period
- Root cause analysis within 48 hours
- Remediation plan within 1 week
```

**In plain English:** SLI measures reality, SLO sets expectations, SLA adds money and lawyers.

> **💡 Insight**
>
> Internal teams rarely have SLAs—no money changes hands. However, setting clear SLOs prevents mismatched expectations. When you say "Kafka is highly available," do you mean 99%, 99.9%, or 99.99%? SLOs make this explicit.

#### Common Terminology Confusion

```
What People Say     What They Mean
────────────────    ──────────────
"Our SLA is..."     Usually means SLO
"SLA violation"     Usually means SLO breach
"SLA targets"       Usually means SLO targets
```

### 3.2. What Metrics Make Good SLIs?

**Key principle:** Measure from the customer's perspective (external, objective metrics)

**SLI Quality Hierarchy:**
```
Best:       Client-side metrics (actual customer experience)
Good:       Synthetic clients (simulated customer experience)
OK:         Infrastructure metrics (network layer measurements)
Avoid:      Broker metrics (Kafka's subjective view)
```

#### Common SLI Types

| Type | Measures | Example |
|------|----------|---------|
| Availability | Can requests complete? | 99.9% of produce requests succeed |
| Latency | How fast are responses? | 95% of fetch requests < 100ms |
| Quality | Are responses correct? | 99.99% of messages delivered exactly once |
| Security | Are requests protected? | 100% of connections use TLS |
| Throughput | Enough data, fast enough? | Support 1M msg/sec sustained |

#### Counter-Based vs. Percentile-Based SLIs

**Good: Counter-based (each event checked)**
```
Count events in SLO:     995,000 requests < 10ms
Count total events:    1,000,000 requests total
Calculate SLI:              995,000 / 1,000,000 = 99.5%
```

**Problematic: Percentile-based**
```
99th percentile = 8ms

This tells us: "99% of requests were faster than 8ms"
But NOT: "99% of requests were under our 10ms target"

The 10ms threshold might include 95% or 99.9% of requests—we can't control it!
```

**Better: Histogram buckets**
```
< 10ms:      995,000 requests
10-50ms:       4,000 requests
50-100ms:        800 requests
100-500ms:       200 requests
> 500ms:           0 requests
──────────
Total:     1,000,000 requests

SLI = 995,000 / 1,000,000 = 99.5%
```

> **💡 Insight**
>
> Percentiles answer "what timing covers 99% of requests?" Counters answer "what percent meets our target?" For SLOs, you want the latter—precise control over your quality threshold.

### 3.3. Using SLOs in Alerting

**Principle:** SLOs should drive primary alerts (they represent customer pain)

#### The Challenge: Long Timeframes

**Problem:**
```
SLO: 99.9% availability over 7 days

Week Timeline:
Monday: 99.85% ✓ (within SLO)
Tuesday: 99.87% ✓
Wednesday: 99.82% ✓
Thursday: 99.70% ✗ (below SLO)
                    ↑
                By the time alert fires, you've already breached!
```

**Solution: SLO Burn Rate**

**In plain English:** Burn rate measures how fast you're using up your error budget—like checking fuel consumption rate, not just fuel level.

#### SLO Burn Rate Example

**Setup:**
- 1,000,000 requests per week
- 99.9% SLO = can tolerate 1,000 bad requests per week
- Normal: 1 slow request/hour = 168 bad requests/week (0.1% burn rate)

**Scenario:**
```
Tuesday 10am:   Burn rate → 0.4%/hour
                Action: Open ticket (not urgent)
                Budget: Will finish week at 99.5% ✓

Wednesday 2pm:  Burn rate → 2%/hour
                Action: Alert fires! 🚨
                Risk: Will breach SLO by Friday lunch

Wednesday 6pm:  Fix deployed
                Burn rate → 0.4%/hour
                Result: Finish week at 99.92% ✓
```

**Burn rate calculation:**
```
Burn rate = (bad events/hour) / (total events/hour)

Normal:     (1/hour) / (5,952/hour) = 0.017% per hour
Problem:    (119/hour) / (5,952/hour) = 2% per hour

At 2% burn rate:
  Total budget: 1,000 bad requests
  Burn rate: ~119 bad requests/hour
  Time to breach: 1,000 / 119 = ~8.4 hours
```

> **💡 Insight**
>
> SLO burn rate transforms a lagging indicator (weekly SLO) into a leading indicator (hourly burn rate). This gives you time to fix problems before customers are impacted.

**Recommended reading:** "Site Reliability Engineering" and "The Site Reliability Workbook" by Betsy Beyer et al. (O'Reilly)

---

## 4. Kafka Broker Metrics

Kafka provides hundreds of broker metrics. This section covers the essential metrics for daily operations.

> **💡 Insight**
>
> If you use Kafka for your own monitoring system (common pattern), ensure Kafka monitoring doesn't depend on Kafka working. Use a separate monitoring system or cross-datacenter metrics (DC-A's Kafka monitored by DC-B's system).

### 4.1. Diagnosing Cluster Problems

Three major problem categories:

```
Problem Type              Impact                    Diagnosis Difficulty
────────────              ──────                    ───────────────────
Single broker             Isolated                  Easy (outliers visible)
Overloaded cluster        Widespread                Medium (resource exhaustion)
Controller issues         Unpredictable             Hard (metadata corruption)
```

#### Single-Broker Problems

**In plain English:** One broker is the "slow car" in traffic—everyone else is fine, but this one is struggling.

**Detection approach:**
1. Monitor OS metrics (CPU, disk, network) for outliers
2. Check storage device health
3. Look for imbalanced partition distribution
4. Identify hot partitions (unevenly accessed data)

**Solution tools:**
- Cruise Control: Automatic continuous rebalancing
- Manual partition reassignment (Chapter 12)

#### Preferred Replica Elections

**First step in troubleshooting:** Run preferred replica election

**Why it helps:**
```
Normal Operation:
  Broker 1: Leader for partitions A, C, E
  Broker 2: Leader for partitions B, D, F

After Broker 1 restart:
  Broker 1: Leader for nothing (lost leadership)
  Broker 2: Leader for partitions A, B, C, D, E, F (overloaded!)

After preferred replica election:
  Broker 1: Leader for partitions A, C, E (rebalanced ✓)
  Broker 2: Leader for partitions B, D, F (rebalanced ✓)
```

**In plain English:** Brokers don't automatically reclaim leadership after recovery. Preferred replica election is like a "reset to defaults" button—safe and effective.

#### Overloaded Clusters

**Symptoms:**
- Elevated latency across many brokers
- Low request handler idle ratio
- Even distribution of load

**Diagnosis:**
```
Step 1: Confirm cluster is balanced
Step 2: Check request handler pool idle ratio
Step 3: Identify problematic clients (if any)
```

**Solutions:**
1. Reduce load (optimize or throttle clients)
2. Increase cluster capacity (add brokers)

#### Controller Problems

**In plain English:** The controller is Kafka's "manager"—when it has problems, weird things happen that break normal patterns.

**Symptoms:**
- Broker metadata out of sync
- Offline replicas on healthy brokers
- Topic operations failing silently
- "That's really weird" moments

**Limited monitoring available:**
- Active controller count (should be 1)
- Controller queue size (should be low)

> **💡 Insight**
>
> Controller issues are often Kafka bugs. If you're saying "This makes no sense," you're probably dealing with a controller problem. Check Kafka release notes and consider upgrading.

### 4.2. The Art of Under-Replicated Partitions

**Under-Replicated Partitions (URP):** Count of partitions where followers haven't caught up to the leader

**Metric details:**
- **JMX MBean:** `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions`
- **Value range:** Integer, zero or greater
- **Expected value:** 0 (always!)

**In plain English:** URP is the "check engine" light for Kafka—it indicates many different problems, which is both its strength and weakness.

#### The URP Alerting Trap

**Historical advice:** "Alert on URP—it catches everything!"

**Modern advice:** "Don't alert on URP—it's too noisy and requires expert interpretation."

**Why the change?**
```
URP can be nonzero for benign reasons:
  - Broker restart in progress
  - Preferred replica election running
  - Partition reassignment active
  - Normal replication lag spikes

Result: False alerts → Alert fatigue → Ignored alerts
```

**Better approach:** Use SLO-based alerting (Section 3.3) to detect problems objectively

#### Diagnosing URP Issues

**Pattern 1: Steady URP on many brokers**
```
Broker 1: URP = 100
Broker 2: URP = 100  } Total = 300 partitions
Broker 3: URP = 100
Broker 4: (no metric reported)

Diagnosis: Broker 4 is offline (owns ~300 partitions)
Action: Investigate Broker 4 hardware/software failure
```

**Pattern 2: Fluctuating URP**
```
Broker 1: URP = 50... 75... 60... 80 (fluctuating)
Broker 2: URP = 30... 45... 35... 50 (fluctuating)

Diagnosis: Performance issue (cluster or single broker)
Action: Deeper investigation needed
```

#### Finding the Problem Broker

**Example scenario:**
```bash
# kafka-topics.sh --bootstrap-server kafka1.example.com:9092/kafka-cluster \
  --describe --under-replicated

Topic: topicOne   Partition: 5    Leader: 1    Replicas: 1,2 Isr: 1
Topic: topicOne   Partition: 6    Leader: 3    Replicas: 2,3 Isr: 3
Topic: topicTwo   Partition: 3    Leader: 4    Replicas: 2,4 Isr: 4
Topic: topicTwo   Partition: 7    Leader: 5    Replicas: 5,2 Isr: 5
Topic: topicSix   Partition: 1    Leader: 3    Replicas: 2,3 Isr: 3
Topic: topicSix   Partition: 2    Leader: 1    Replicas: 1,2 Isr: 1
Topic: topicSix   Partition: 5    Leader: 6    Replicas: 2,6 Isr: 6
Topic: topicSix   Partition: 7    Leader: 7    Replicas: 7,2 Isr: 7
Topic: topicNine  Partition: 1    Leader: 1    Replicas: 1,2 Isr: 1
Topic: topicNine  Partition: 3    Leader: 3    Replicas: 2,3 Isr: 3
Topic: topicNine  Partition: 4    Leader: 3    Replicas: 3,2 Isr: 3
Topic: topicNine  Partition: 7    Leader: 3    Replicas: 2,3 Isr: 3
Topic: topicNine  Partition: 0    Leader: 3    Replicas: 2,3 Isr: 3
Topic: topicNine  Partition: 5    Leader: 6    Replicas: 6,2 Isr: 6
```

**Analysis:**
```
Look for common broker in "Replicas" but not in "Isr":
  - Broker 2 appears in all Replicas lists
  - Broker 2 missing from all Isr lists

Conclusion: Broker 2 has replication problems
```

> **💡 Insight**
>
> The Isr (In-Sync Replicas) list is the key diagnostic. Replicas shows the plan; Isr shows reality. A broker in Replicas but not Isr is struggling to keep up.

### 4.3. Cluster-Level Problems

Two primary categories:

#### Unbalanced Load

**Diagnostic metrics:**
- Partition count per broker
- Leader partition count per broker
- All topics messages in rate
- All topics bytes in rate
- All topics bytes out rate

**Example of balanced cluster:**

| Broker | Partitions | Leaders | Messages/sec | Bytes In | Bytes Out |
|--------|------------|---------|--------------|----------|-----------|
| 1 | 100 | 50 | 13,130 | 3.56 MBps | 9.45 MBps |
| 2 | 101 | 49 | 12,842 | 3.66 MBps | 9.25 MBps |
| 3 | 100 | 50 | 13,086 | 3.23 MBps | 9.82 MBps |

**In plain English:** In a perfectly balanced cluster, all numbers are nearly identical—like three workers doing equal amounts of work.

**Solution:** Use `kafka-reassign-partitions.sh` (Chapter 12) or automated tools like kafka-assigner

#### Resource Exhaustion

**Common bottlenecks:**
- CPU utilization
- Disk I/O throughput
- Network throughput
- Disk average wait time

**Not a bottleneck:** Disk space utilization (until disk is full, then abrupt failure)

**Critical OS metrics:**

| Metric | Description | Warning Signs |
|--------|-------------|---------------|
| CPU utilization | Processor usage | Load average > CPU count |
| Inbound network | Bytes in/sec | Approaching NIC limit |
| Outbound network | Bytes out/sec | Approaching NIC limit |
| Disk avg wait time | I/O latency | > 10ms consistently |
| Disk % utilization | I/O queue depth | > 80% consistently |

> **💡 Insight**
>
> Broker replication uses the same path as client requests. If replication is slow (URP), clients are also experiencing slowness. Fix replication issues to fix client performance.

**Best practice:** Establish baselines during normal operation, set thresholds before exhaustion

### 4.4. Host-Level Problems

When issues isolate to one or two brokers:

#### Problem Categories

```
Hardware Failures
        ↓
    Networking Issues
        ↓
    Process Conflicts
        ↓
    Configuration Drift
```

#### Hardware Failures

**Soft failures** (degraded performance):
- Bad memory segment (reduced available RAM)
- CPU failure (reduced processing power)
- Disk failure (slow I/O)

**Monitoring tools:**
- IPMI (Intelligent Platform Management Interface)
- `dmesg` (kernel ring buffer for errors)
- SMART tools (disk health monitoring)
- RAID controller status (especially BBU health)

**One bad disk, cluster-wide impact:**
```
Producer writes to topic with 10 partitions across 10 brokers:
  - 9 brokers respond in 5ms
  - 1 broker (bad disk) responds in 500ms
  - Producer waits for all acks → 500ms total latency

Result: Single slow disk destroys entire cluster performance
```

> **💡 Insight**
>
> Kafka's distributed architecture means one slow component affects everyone. This is why proactive hardware monitoring is critical—replace failing disks before they impact the cluster.

#### Networking Problems

**Hardware issues:**
- Bad network cable
- Faulty connector
- Failed network interface

**Configuration issues:**
- Speed/duplex mismatch
- Network buffer under-sizing
- Connection pool exhaustion

**Detection:** Monitor network interface error counts (increasing = problem)

#### Process Conflicts

**Common culprits:**
- Misconfigured applications
- Runaway monitoring agents
- Competing applications

**Detection:** Use `top` to identify CPU/memory hogs

#### Configuration Drift

**Prevention:** Use configuration management systems
- Chef
- Puppet
- Ansible
- SaltStack

**In plain English:** Manual configuration changes lead to "snowflake servers"—each one slightly different, making troubleshooting impossible. Automation ensures consistency.

### 4.5. Broker Metrics

Essential broker-level metrics beyond URP:

#### Active Controller Count

**What it measures:** Whether this broker is the cluster controller

**Metric details:**
- **JMX MBean:** `kafka.controller:type=KafkaController,name=ActiveControllerCount`
- **Value range:** 0 or 1
- **Expected:** Exactly 1 broker reports 1; all others report 0

**Problem scenarios:**

```
Scenario 1: Two controllers
  Broker 1: ActiveControllerCount = 1
  Broker 3: ActiveControllerCount = 1

  Problem: Split brain (controller thread stuck)
  Impact: Admin operations fail or behave unpredictably
  Solution: Restart both brokers (forced shutdown may be needed)

Scenario 2: No controller
  All brokers: ActiveControllerCount = 0

  Problem: No controller elected
  Impact: Cluster cannot respond to state changes
  Root cause: Often ZooKeeper connectivity issues
  Solution: Fix ZK connection, restart all brokers
```

#### Controller Queue Size

**What it measures:** Number of requests waiting for controller to process

**Metric details:**
- **JMX MBean:** `kafka.controller:type=ControllerEventManager,name=EventQueueSize`
- **Value range:** Integer, zero or more
- **Expected:** 0 most of the time, brief spikes acceptable

**Problem scenarios:**
```
Normal: 0 → 5 → 2 → 0 → 8 → 1 → 0 (fluctuating, returns to zero)

Problem: 0 → 10 → 25 → 47 → 95 → 150 (continuously increasing)
         OR
         Stuck at 500 for extended period

Diagnosis: Controller is stuck
Impact: Admin operations frozen
Solution: Move controller to different broker (shutdown current)
```

#### Request Handler Idle Ratio

**What it measures:** Percentage of time request handler threads are idle

**In plain English:** Like restaurant servers—if they're 100% busy, orders get delayed. If they're 80% idle, there's plenty of capacity.

**Metric details:**
- **JMX MBean:** `kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent`
- **Value range:** Float, 0.0 to 1.0 (0% to 100%)
- **Expected:** > 0.2 (above 20%)

**Thread pool architecture:**
```
Client Request → Network Thread (read/write) → Request Handler Thread (process)
                  (Less critical)                 (Critical bottleneck)
```

**Performance thresholds:**
```
> 20%:  Healthy
10-20%: Warning (potential problem)
< 10%:  Critical (active performance problem)
```

**Sizing guidance:** Set thread count = CPU count (including hyperthreaded cores)

**Performance optimization:**
```
Old (< 0.10): Broker decompresses → validates → assigns offsets → recompresses
              All behind synchronous lock (very slow!)

New (≥ 0.10): Relative offsets in message batch
              Broker skips decompression/recompression (much faster!)

Action: Upgrade all clients and brokers to ≥ 0.10 message format
```

> **💡 Insight**
>
> Kafka uses "purgatory" for long-running requests (quota enforcement, waiting for acks), freeing request handler threads. This intelligent design means you need fewer threads than you might expect.

#### All Topics Bytes In

**What it measures:** Producer traffic rate in bytes per second

**Metric details:**
- **JMX MBean:** `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec`
- **Value range:** Rates as doubles, count as integer

**Rate metric attributes explained:**

```
Descriptive Attributes:
  EventType: "bytes"
  RateUnit: "seconds"
  (Meaning: All rates measured in bytes per second)

Rate Attributes:
  OneMinuteRate:     Average over last 1 minute (volatile, shows spikes)
  FiveMinuteRate:    Average over last 5 minutes (balanced)
  FifteenMinuteRate: Average over last 15 minutes (smooth)
  MeanRate:          Average since broker start (trend line)

Counter Attribute:
  Count:             Total bytes since broker start
```

**Choosing the right attribute:**
```
OneMinuteRate:     Traffic spike detection
FiveMinuteRate:    Alerting threshold (recommended)
FifteenMinuteRate: Stable view for dashboards
MeanRate:          Long-term trend analysis
Count:             Absolute measurement (with counter-aware metrics system)
```

**Use cases:**
- **Growth planning:** Track trend over time
- **Cluster balancing:** Compare across brokers (should be even)
- **Capacity planning:** Predict when to expand

#### All Topics Bytes Out

**What it measures:** Consumer + replication traffic rate in bytes per second

**Metric details:**
- **JMX MBean:** `kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec`
- **Value range:** Rates as doubles, count as integer

**Important:** Includes replica fetchers, not just consumers!

**Traffic calculation example:**
```
Replication factor = 2
Consumer groups = 6

Bytes in rate: 100 MBps

Bytes out breakdown:
  Replication:  100 MBps (factor 2 means 1:1 replication traffic)
  Consumers:    600 MBps (6 consumer groups × 100 MBps)
  Total out:    700 MBps

Ratio: 7:1 outbound to inbound
```

**In plain English:** Kafka's superpower is serving the same data to many consumers. Outbound traffic often exceeds inbound by 6-10x!

#### All Topics Messages In

**What it measures:** Producer message count per second (regardless of message size)

**Metric details:**
- **JMX MBean:** `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec`
- **Value range:** Rates as doubles, count as integer

**Combined with Bytes In:**
```
Bytes In Rate: 100 MBps
Messages In Rate: 10,000 msg/sec

Average message size: 100,000,000 / 10,000 = 10 KB per message
```

**Use cases:**
- Growth metric (different dimension than bytes)
- Message size analysis
- Cluster balance verification

**Why no "Messages Out" metric?**

**In plain English:** When consumers fetch, the broker sends raw batches without counting individual messages—it would be too expensive to decompress and count them.

**Available alternative:** Fetch requests per second (request rate, not message count)

#### Partition Count

**What it measures:** Total partitions on this broker (leader + follower)

**Metric details:**
- **JMX MBean:** `kafka.server:type=ReplicaManager,name=PartitionCount`
- **Value range:** Integer, zero or greater
- **Stability:** Usually stable (changes only with topic/partition operations)

**Useful when:**
- Automatic topic creation enabled
- Tracking partition sprawl
- Capacity planning

#### Leader Count

**What it measures:** Number of partitions this broker leads

**Metric details:**
- **JMX MBean:** `kafka.server:type=ReplicaManager,name=LeaderCount`
- **Value range:** Integer, zero or greater
- **Expected:** Even distribution across cluster

**Critical for cluster balance:**
```
Replication factor 2:
  Expected leader percentage: 50% of partitions

Replication factor 3:
  Expected leader percentage: 33% of partitions

Example (RF=2):
  Broker 1: 100 partitions, 50 leaders (50% ✓)
  Broker 2: 100 partitions, 5 leaders (5% ✗)

Action needed: Run preferred replica election
```

**Useful metric combination:**
```
Leader percentage = (LeaderCount / PartitionCount) × 100%

Should equal: 100% / ReplicationFactor
```

> **💡 Insight**
>
> Leader count is more important than partition count for balance. A broker with many partitions but few leaders is underutilized. All read/write traffic goes to leaders, so leader imbalance = traffic imbalance.

#### Offline Partitions

**What it measures:** Partitions without a leader (cluster-wide)

**Metric details:**
- **JMX MBean:** `kafka.controller:type=KafkaController,name=OfflinePartitionsCount`
- **Value range:** Integer, zero or greater
- **Expected:** 0 (always!)
- **Reported by:** Only the controller (all other brokers report 0)

**Causes:**

```
Scenario 1: All brokers hosting replicas are down
  Topic: critical-data, Partition: 0, RF: 3
  Replicas on: Brokers 1, 2, 3

  All three brokers offline → Partition offline

Scenario 2: No ISR can take leadership (unclean leader election disabled)
  Topic: critical-data, Partition: 0
  Leader: Broker 1 (crashed with uncommitted messages)
  ISR: Broker 1 only
  Followers: Brokers 2, 3 (not in sync)

  No ISR available → Partition offline (data safety over availability)
```

**Impact:** Production cluster outage—producers blocked or dropping messages

**Severity:** "Site down" level problem requiring immediate response

### 4.6. Request Metrics

Kafka tracks detailed metrics for every request type in the protocol.

#### Available Request Types (Kafka 2.5.0)

```
Producer/Consumer:        Admin:                    Internal:
──────────────────        ──────                    ─────────
Produce                   CreateTopics              LeaderAndIsr
Fetch                     DeleteTopics              UpdateMetadata
FetchConsumer             CreatePartitions          StopReplica
FetchFollower             CreateAcls                ControlledShutdown
Metadata                  DeleteAcls
ListOffsets               AlterConfigs
                          DescribeConfigs
Consumer Groups:          ElectLeaders
────────────────
JoinGroup                 Transactions:
SyncGroup                 ─────────────
Heartbeat                 InitProducerId
LeaveGroup                AddPartitionsToTxn
OffsetCommit              AddOffsetsToTxn
OffsetFetch               EndTxn
OffsetDelete              TxnOffsetCommit
FindCoordinator           WriteTxnMarkers
DescribeGroups
DeleteGroups              (Plus 20+ more...)
ListGroups
```

#### Metrics per Request Type

For each request (using Fetch as example):

| Metric | JMX MBean |
|--------|-----------|
| Total time | `kafka.network:type=RequestMetrics,name=TotalTimeMs,request=Fetch` |
| Request queue time | `kafka.network:type=RequestMetrics,name=RequestQueueTimeMs,request=Fetch` |
| Local time | `kafka.network:type=RequestMetrics,name=LocalTimeMs,request=Fetch` |
| Remote time | `kafka.network:type=RequestMetrics,name=RemoteTimeMs,request=Fetch` |
| Throttle time | `kafka.network:type=RequestMetrics,name=ThrottleTimeMs,request=Fetch` |
| Response queue time | `kafka.network:type=RequestMetrics,name=ResponseQueueTimeMs,request=Fetch` |
| Response send time | `kafka.network:type=RequestMetrics,name=ResponseSendTimeMs,request=Fetch` |
| Requests per second | `kafka.network:type=RequestMetrics,name=RequestsPerSec,request=Fetch` |

#### Request Processing Phases

```
Client Request Arrives
        ↓
[Request Queue Time] ← Waiting for request handler
        ↓
[Local Time] ← Leader processes request, writes to disk
        ↓
[Remote Time] ← Waiting for follower acks
        ↓
[Throttle Time] ← Delay for quota enforcement
        ↓
[Response Queue Time] ← Waiting for network thread
        ↓
[Response Send Time] ← Sending bytes over network
        ↓
Total Time = Sum of all phases
```

**In plain English:** Request processing is like a package moving through a shipping facility—it spends time in various queues and processing stations.

#### Time Metric Attributes

All timing metrics provide:

| Attribute | Description |
|-----------|-------------|
| Count | Total number of requests since broker start |
| Min | Minimum value observed |
| Max | Maximum value observed |
| Mean | Average value |
| StdDev | Standard deviation |
| 50thPercentile | Median (50% faster, 50% slower) |
| 75thPercentile | 75% of requests faster than this |
| 95thPercentile | 95% of requests faster than this |
| 98thPercentile | 98% of requests faster than this |
| 99thPercentile | 99% of requests faster than this |
| 999thPercentile | 99.9% of requests faster than this |

**Understanding percentiles:**
```
99th Percentile = 10ms

Meaning: 99% of requests completed in ≤ 10ms
         1% of requests took > 10ms (outliers)

Alerting pattern:
  Average: 5ms         (typical request)
  99.9th:  50ms        (worst-case request)

  If 99.9th spikes to 500ms → Alert!
```

> **💡 Insight**
>
> Average alone is misleading—a few very slow requests pull the average up while most users suffer. Percentiles show the distribution: how many users experience which latency.

#### Recommended Metrics Collection

**Minimum (all request types):**
- Total time (mean + 99th or 99.9th percentile)
- Requests per second

**Ideal (all request types):**
- All seven timing metrics (mean + high percentile)
- Allows pinpointing which phase is slow

**Alerting recommendations:**
- **Produce total time 99.9th percentile**: Set baseline threshold
  - Sharp increase indicates wide range of problems
  - Similar to URP but more specific to producer impact
- **Fetch total time**: Harder to alert on
  - Varies with client config (fetch.max.wait.ms)
  - Slow topics have erratic timing

### 4.7. Topic and Partition Metrics

Individual topic and partition metrics provide detailed debugging information.

**Challenge:** Large clusters can have tens of thousands of these metrics

#### Per-Topic Metrics

| Metric | JMX MBean |
|--------|-----------|
| Bytes in rate | `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec,topic=TOPICNAME` |
| Bytes out rate | `kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec,topic=TOPICNAME` |
| Failed fetch rate | `kafka.server:type=BrokerTopicMetrics,name=FailedFetchRequestsPerSec,topic=TOPICNAME` |
| Failed produce rate | `kafka.server:type=BrokerTopicMetrics,name=FailedProduceRequestsPerSec,topic=TOPICNAME` |
| Messages in rate | `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec,topic=TOPICNAME` |
| Fetch request rate | `kafka.server:type=BrokerTopicMetrics,name=TotalFetchRequestsPerSec,topic=TOPICNAME` |
| Produce request rate | `kafka.server:type=BrokerTopicMetrics,name=TotalProduceRequestsPerSec,topic=TOPICNAME` |

**Use cases:**
- Identify specific topic causing traffic spike
- Debugging client issues with particular topic
- Providing metrics to topic owners (chargeback/showback)

**Practical considerations:**
```
Small deployment (10 topics):
  ✓ Collect all per-topic metrics

Medium deployment (100 topics):
  ✓ Collect selectively or on-demand

Large deployment (1,000+ topics):
  ✗ Don't collect all metrics continuously
  ✓ Make available via JMX for debugging
  ✓ Provide to topic owners for self-service
```

#### Per-Partition Metrics

| Metric | JMX MBean |
|--------|-----------|
| Partition size | `kafka.log:type=Log,name=Size,topic=TOPICNAME,partition=0` |
| Log segment count | `kafka.log:type=Log,name=NumLogSegments,topic=TOPICNAME,partition=0` |
| Log end offset | `kafka.log:type=Log,name=LogEndOffset,topic=TOPICNAME,partition=0` |
| Log start offset | `kafka.log:type=Log,name=LogStartOffset,topic=TOPICNAME,partition=0` |

**Partition size use cases:**
- Cost allocation (disk usage per topic)
- Detecting uneven key distribution
  ```
  Topic: user-events (10 partitions)

  Partition 0: 100 GB
  Partition 1: 95 GB
  Partition 2: 98 GB
  Partition 3: 5 GB ← Problem! Key hashing issue
  Partition 4: 97 GB
  ...
  ```

**Log offset use cases:**
- Timestamp-to-offset mapping
- Consumer position tracking
- Less critical since Kafka 0.10.1 (time-based index searching added)

**Important caveat:**
```
Log end offset - Log start offset ≠ Message count

Reason: Log compaction removes messages, creating "gaps" in offsets

Example:
  Log start offset: 1000
  Log end offset: 5000

  Apparent count: 4000 messages
  Actual count: Could be 3500 (500 compacted away)
```

---

## 5. JVM Monitoring

Kafka runs on the Java Virtual Machine—monitor JVM health separately.

### 5.1. Garbage Collection

**In plain English:** Garbage collection is like taking out the trash—it's necessary but stops other work while it happens.

#### G1 Garbage Collector Metrics (Java 8+)

| Metric | JMX MBean |
|--------|-----------|
| Full GC cycles | `java.lang:type=GarbageCollector,name=G1 Old Generation` |
| Young GC cycles | `java.lang:type=GarbageCollector,name=G1 Young Generation` |

**Key attributes:**

```
CollectionCount:  Number of GC cycles since JVM start
CollectionTime:   Milliseconds spent in GC since JVM start

Useful derived metrics:
  GC cycles per minute:  Rate of CollectionCount
  GC time per minute:    Rate of CollectionTime
  Avg time per GC:       CollectionTime / CollectionCount
```

**LastGcInfo composite attribute:**
```
duration:      Last GC cycle duration in milliseconds (KEY METRIC)
GcThreadCount: Threads used for GC (informational)
id:            GC cycle ID (informational)
startTime:     When GC started (informational)
endTime:       When GC ended (informational)
```

**Monitoring approach:**
```
Primary:   Track CollectionCount and CollectionTime rates
Secondary: Monitor LastGcInfo.duration for individual cycle spikes
```

> **💡 Insight**
>
> Young GC cycles are frequent and fast (milliseconds). Full GC cycles are rare and slow (seconds). If Full GC becomes frequent, you have a memory leak or undersized heap.

### 5.2. Java OS Monitoring

**JMX Bean:** `java.lang:type=OperatingSystem`

**Critical attributes:**

```
MaxFileDescriptorCount:  Maximum FDs allowed
OpenFileDescriptorCount: FDs currently open

FD consumption sources:
  - Log segment files (every segment = 1 FD)
  - Network connections (every client = 1 FD)
  - Internal operations
```

**File descriptor exhaustion scenario:**
```
Broker has 1,000 partitions
Average 10 log segments per partition
= 10,000 FDs for log files

500 client connections
= 500 FDs for network

Total: ~10,500 FDs in use

If MaxFileDescriptorCount = 10,000 → Approaching limit!
Result: Cannot accept new connections or create new log segments
```

**In plain English:** File descriptors are like parking spaces—you need enough for everyone who might show up. Run out, and new arrivals are turned away.

---

## 6. OS Monitoring

The JVM can't tell you everything—monitor the OS directly.

**Essential OS metrics:**

| Category | Metrics | Critical Thresholds |
|----------|---------|---------------------|
| CPU | System load average, % usage breakdown | Load > CPU count |
| Memory | Used, free, swap usage | Swap > 0 |
| Disk | Usage (space + inodes), I/O stats | I/O wait > 10ms |
| Network | Inbound/outbound throughput | Approaching NIC limit |

### CPU Utilization

**System load average:**
```
Load Average: 1.5, 2.3, 3.1
               ↓    ↓    ↓
            1min 5min 15min

Interpretation (24-CPU system):
  1.5:  6% loaded (healthy)
  2.3:  10% loaded (healthy)
  3.1:  13% loaded (healthy)

Interpretation (2-CPU system):
  1.5:  75% loaded (warning)
  2.3:  115% loaded (overloaded!)
  3.1:  155% loaded (critical!)
```

**In plain English:** Load average counts processes waiting for CPU time. On a system with N CPUs, load N means 100% utilized. Load 2N means 200% oversubscribed (processes waiting).

**CPU time breakdown:**

| Abbreviation | Meaning | Kafka Relevance |
|--------------|---------|-----------------|
| us (user) | User space processing | High for Kafka (request processing) |
| sy (system) | Kernel space processing | Moderate (disk I/O, network) |
| ni (nice) | Low-priority processes | Should be low |
| id (idle) | Idle time | Want this high! |
| wa (wait) | Waiting for disk | High = disk bottleneck |
| hi (hardware interrupts) | Hardware interrupt handling | Moderate (network interrupts) |
| si (software interrupts) | Software interrupt handling | Should be low |
| st (steal) | Waiting for hypervisor | High = VM oversubscription |

**Kafka CPU profile:**
```
Healthy broker:
  us: 40%  (request processing)
  sy: 20%  (kernel operations)
  wa: 5%   (disk wait)
  id: 35%  (idle capacity)

Problem scenarios:
  wa: 40% → Disk bottleneck
  st: 30% → VM host oversubscribed
  us: 95% → CPU-bound processing
```

### Memory Utilization

**In plain English:** Kafka deliberately uses most system memory for OS page cache (file caching). Low free memory is normal; swap usage is not.

**Critical rule:** Swap usage = problem

```
Normal Kafka broker:
  Total RAM: 64 GB
  JVM heap: 6 GB
  Free RAM: 2 GB
  Cached: 56 GB ← OS caching log files
  Swap used: 0 GB ✓

Problem broker:
  Total RAM: 64 GB
  Swap used: 4 GB ✗ ← Performance killer

Cause: Another application consuming memory
       or memory leak in JVM
```

### Disk Monitoring

**Most critical subsystem for Kafka!**

**Space metrics:**
```
Disk usage (bytes):   How full is the disk?
Inode usage (count):  How many files/directories?
```

**Kafka characteristic:** Fills disk steadily until retention cleanup

**I/O performance metrics:**

| Metric | Description | Healthy Threshold |
|--------|-------------|-------------------|
| Reads/sec | Read operations per second | Varies by workload |
| Writes/sec | Write operations per second | Varies by workload |
| Avg read queue | Requests waiting to read | < 10 |
| Avg write queue | Requests waiting to write | < 10 |
| Avg wait time | Time requests wait | < 10ms |
| % utilization | Disk busy percentage | < 80% |

**One bad disk destroys cluster performance:**

```
Cluster: 10 brokers
Topic: important-data, 10 partitions, RF=2

Producer writes to all 10 partitions:
  Broker 1-9: Respond in 5ms
  Broker 10: Respond in 500ms (bad disk)

Producer waits for all acks:
  Total latency: 500ms (slowest wins!)

Impact: All producers to this topic slowed 100x
        Back pressure cascades to entire application
```

> **💡 Insight**
>
> Distributed systems are only as fast as their slowest component. One failing disk can create cluster-wide latency. This is why proactive disk monitoring and rapid hardware replacement is critical.

**Disk health monitoring tools:**
- **SMART:** Self-Monitoring, Analysis and Reporting Technology
- **IPMI:** Hardware interface for disk status
- **RAID controller:** Monitor cache status and BBU (battery backup unit)

**BBU failure impact:**
```
RAID controller with BBU:
  Normal: Write cache enabled (fast writes)
  BBU failure: Write cache disabled (slow writes!)

Performance impact: 5-10x slower writes
```

### Network Monitoring

**Key metrics:**
- Inbound bits per second
- Outbound bits per second
- Network interface errors

**Traffic calculation:**
```
Inbound: 100 Mbps
Replication factor: 3
Consumer groups: 5

Outbound calculation:
  Replication: 200 Mbps (RF-1 = 2 copies sent to followers)
  Consumers: 500 Mbps (5 groups × 100 Mbps)
  Total: 700 Mbps

Ratio: 7:1 outbound to inbound
```

**Interface errors:** Any increasing error count indicates hardware/config problem

---

## 7. Logging

**In plain English:** Kafka can generate gigabytes of logs per hour if you let it. Strategic logging configuration provides useful information without filling disks.

### Recommended Logger Configuration

#### Standard Loggers (INFO level)

**General broker logging:**
```
Root logger: INFO level
```

**Separated loggers:**

| Logger | Level | Purpose | Content |
|--------|-------|---------|---------|
| kafka.controller | INFO | Controller actions | Topic creation, broker changes, elections |
| kafka.server.ClientQuotaManager | INFO | Quota enforcement | Throttling events |

**Why separate?**
- Controller: Only active on one broker, important cluster events
- Quota manager: High volume, better in separate file

#### Log Compaction Loggers (DEBUG level)

```
kafka.log.LogCleaner:        DEBUG
kafka.log.Cleaner:           DEBUG
kafka.log.LogCleanerManager: DEBUG
```

**Why debug level?**
- Log compaction failures can be silent
- Debug logging shows health of compaction threads
- Low volume under normal operation
- Critical for detecting compaction deadlocks

**Example log compaction output:**
```
[DEBUG] LogCleaner: Starting cleaning of partition topic-0
[DEBUG] Cleaner: Cleaned partition topic-0, 5000 messages, 500 MB
[DEBUG] LogCleanerManager: Compaction thread health check passed
```

#### Debug Loggers (temporary use only)

**Request logging:**
```
kafka.request.logger: DEBUG or TRACE

DEBUG level:
  - Connection endpoints
  - Request timings
  - Summary information

TRACE level:
  - Everything in DEBUG
  - Topic and partition details
  - Nearly complete request data (excludes payload)
```

**Warning:** Generates massive log volume—use only when debugging specific issues

**Example usage scenario:**
```
Problem: Mysterious latency spikes
Action: Enable kafka.request.logger at DEBUG for 5 minutes
Analysis: Identify slow request types and sources
Action: Disable logger, fix identified issues
```

> **💡 Insight**
>
> Logging is a debugging tool, not a monitoring solution. Use metrics for continuous monitoring, logs for post-mortem analysis and debugging active issues.

---

## 8. Client Monitoring

Producer and consumer applications have their own metrics independent of brokers.

### 8.1. Producer Metrics

**In plain English:** Producer metrics tell you how well your application is sending messages—are they getting through? How fast? Any errors?

#### Producer Metric Beans

| Category | JMX MBean Pattern |
|----------|-------------------|
| Overall producer | `kafka.producer:type=producer-metrics,client-id=CLIENTID` |
| Per-broker | `kafka.producer:type=producer-node-metrics,client-id=CLIENTID,node-id=node-BROKERID` |
| Per-topic | `kafka.producer:type=producer-topic-metrics,client-id=CLIENTID,topic=TOPICNAME` |

**Note:** CLIENTID, BROKERID, and TOPICNAME are placeholders—substitute actual values

#### Critical Overall Producer Metrics

**record-error-rate (ALERT ON THIS!)**
```
Expected value: 0.0 (always!)
Meaning: Messages dropped after retries exhausted

Any value > 0:
  Problem: Producer is losing messages
  Impact: Data loss
  Action: Investigate broker issues, network problems, or quota limits
```

**request-latency-avg (ALERT ON THIS!)**
```
Baseline: Establish normal value (e.g., 50ms)
Alert threshold: 2-3× baseline (e.g., 150ms)

Increase indicates:
  - Network degradation
  - Broker performance issues
  - Disk slowness on brokers
  - Cluster resource exhaustion
```

#### Traffic Metrics

**Three views of the same data:**

```
outgoing-byte-rate:    Absolute size (bytes/sec)
record-send-rate:      Message count (messages/sec)
request-rate:          Batch count (requests/sec)

Relationship:
  Bytes = Records × Avg Record Size
  Records = Requests × Avg Records per Request
```

**Example:**
```
outgoing-byte-rate: 10 MB/sec
record-send-rate: 10,000 msg/sec
request-rate: 100 req/sec

Derived metrics:
  Avg record size: 10 MB / 10,000 = 1 KB
  Avg records per request: 10,000 / 100 = 100 messages
```

#### Size Metrics

```
request-size-avg:          Avg produce request size (bytes)
batch-size-avg:            Avg message batch size (bytes)
record-size-avg:           Avg individual record size (bytes)
records-per-request-avg:   Avg records in a request
```

**Batching analysis:**
```
Single-topic producer:
  batch-size-avg: 100 KB
  records-per-request-avg: 100

  Derived: Avg record size = 1 KB

Multi-topic producer (e.g., MirrorMaker):
  Less meaningful (averages across diverse topics)
```

#### Latency Metric

**record-queue-time-avg:**
```
Measures: Time messages wait in producer before sending
Unit: Milliseconds

Controlled by:
  batch.size:  Send when batch reaches this size
  linger.ms:   Send after this much time

High traffic topic:
  - Batch fills quickly → Low queue time
  - Controlled by batch.size

Low traffic topic:
  - Batch rarely fills → Higher queue time
  - Controlled by linger.ms

Use for: Tuning latency vs. throughput trade-off
```

**Tuning guidance:**
```
Low latency requirement (10ms):
  linger.ms: 5
  batch.size: 16384 (default)

High throughput requirement:
  linger.ms: 100
  batch.size: 1048576 (1 MB)
```

> **💡 Insight**
>
> Batching is a latency/throughput trade-off. Larger batches mean better network efficiency but longer wait times. Monitor record-queue-time-avg to tune these settings for your requirements.

#### Per-Broker and Per-Topic Metrics

**When useful:**
- Debugging connection issues to specific broker
- Analyzing multi-topic producer behavior
- Isolating problems to specific topic

**When not useful:**
- Too many topics (hundreds or thousands)
- Single-topic producer (redundant with overall metrics)
- Normal operations (too much data)

**Most useful per-broker metric:**
- `request-latency-avg`: Detect slow connections to specific brokers

**Most useful per-topic metrics:**
- `record-send-rate`: Messages per second for this topic
- `record-error-rate`: Errors specific to this topic
- `byte-rate`: Bytes per second for this topic

### 8.2. Consumer Metrics

**In plain English:** Consumer metrics show how well your application is reading messages—are you keeping up? How much lag? Any connection issues?

#### Consumer Metric Beans

| Category | JMX MBean Pattern |
|----------|-------------------|
| Overall consumer | `kafka.consumer:type=consumer-metrics,client-id=CLIENTID` |
| Fetch manager | `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=CLIENTID` |
| Per-topic | `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=CLIENTID,topic=TOPICNAME` |
| Per-broker | `kafka.consumer:type=consumer-node-metrics,client-id=CLIENTID,node-id=node-BROKERID` |
| Coordinator | `kafka.consumer:type=consumer-coordinator-metrics,client-id=CLIENTID` |

#### Fetch Manager Metrics

**fetch-latency-avg:**
```
Measures: Time for fetch requests to complete
Challenge: Varies based on consumer configuration

Affected by:
  fetch.min.bytes:   Minimum bytes before responding
  fetch.max.wait.ms: Maximum wait time for minimum bytes

Slow topic pattern:
  Sometimes: Fast response (messages available)
  Sometimes: Wait full fetch.max.wait.ms (no messages)
  Result: Erratic metric, hard to alert on

Fast topic pattern:
  Consistently: Fast responses (messages always available)
  Result: Stable metric, easier to alert on
```

**Traffic metrics:**

```
bytes-consumed-rate:   Absolute size (bytes/sec)
records-consumed-rate: Message count (messages/sec)
```

**Alerting caution:**
```
Common mistake: Alert on minimum consumption rate

Problem: Consumer rate depends on producer rate
         Kafka decouples producer and consumer
         Producer issue → Consumer slows down → False alert

Better: Monitor lag (Section 9), not consumption rate
```

**Size metrics:**

```
fetch-rate:              Fetch requests per second
fetch-size-avg:          Avg fetch request size (bytes)
records-per-request-avg: Avg records per fetch request
```

**Missing:** No `record-size-avg` (unlike producer)—must calculate from other metrics

#### Per-Broker and Per-Topic Metrics

**Similar guidance as producer:**
- Most useful for debugging
- `request-latency-avg` per-broker can identify connection issues
- Per-topic metrics only useful for multi-topic consumers
- Too many topics make collection impractical

**Per-topic metrics:**
- `bytes-consumed-rate`: Bytes/sec for this topic
- `records-consumed-rate`: Messages/sec for this topic
- `fetch-size-avg`: Avg fetch size for this topic

#### Consumer Coordinator Metrics

**In plain English:** The coordinator manages consumer group membership—which consumer handles which partitions.

**sync-time-avg and sync-rate:**
```
sync-time-avg: Avg time for consumer group synchronization (ms)
sync-rate: Group syncs per second

Stable consumer group:
  sync-rate: 0.0 most of the time
  sync-time-avg: < 1000ms when it happens

Problem patterns:
  sync-rate: > 0.1 (frequent rebalancing)
  sync-time-avg: > 5000ms (slow rebalancing)

Causes:
  - Consumer instances joining/leaving
  - Consumer instances crashing
  - Partition reassignments
  - Many partitions (slow coordination)
```

**commit-latency-avg:**
```
Measures: Time to commit offsets
Meaning: Offset commit is a produce request to __consumer_offsets topic

Similar to producer request-latency-avg:
  - Establish baseline (e.g., 20ms)
  - Alert on significant increases
  - Indicates broker performance issues
```

**assigned-partitions:**
```
Measures: Number of partitions assigned to this consumer instance

Use for: Detecting load imbalance

Example (3 consumers, 10 partitions):
  Consumer A: assigned-partitions = 4
  Consumer B: assigned-partitions = 4
  Consumer C: assigned-partitions = 2

  Imbalance! Consumer C underutilized

Causes:
  - Partition assignment algorithm behavior
  - Consumer group protocol version
```

> **💡 Insight**
>
> Consumer rebalancing stops message processing during synchronization. Frequent rebalances = frequent processing pauses. Monitor sync-rate to catch unstable consumer groups.

### 8.3. Quotas

**In plain English:** Quotas prevent one noisy client from overwhelming the cluster—like rate limiting on an API.

#### How Quotas Work

**Configuration:**
```
Cluster-wide default: 10 MBps per client ID
Per-client override: Client X gets 50 MBps
```

**Enforcement mechanism:**
```
Client exceeds quota → Broker delays response (throttling)
                     → Client naturally slows down
                     → No error codes sent
```

**Important:** Throttling is invisible without monitoring!

#### Quota Metrics

| Client | JMX MBean |
|--------|-----------|
| Consumer | `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=CLIENTID` attribute `fetch-throttle-time-avg` |
| Producer | `kafka.producer:type=producer-metrics,client-id=CLIENTID` attribute `produce-throttle-time-avg` |

**Interpretation:**
```
fetch-throttle-time-avg: 0ms
  → No throttling (within quota)

fetch-throttle-time-avg: 50ms
  → Broker delaying responses by 50ms avg
  → Client is over quota

produce-throttle-time-avg: 200ms
  → Broker delaying responses by 200ms avg
  → Severe quota violation
```

**Best practice:** Monitor even if quotas not currently enabled (preparation for future use)

---

## 9. Lag Monitoring

**In plain English:** Lag is the most important consumer metric—it tells you if your consumer is falling behind.

**Lag definition:**
```
Lag = (Broker Log End Offset) - (Consumer Committed Offset)

Example:
  Broker offset: 1,000,000 (latest message)
  Consumer offset: 995,000 (last processed)
  Lag: 5,000 messages behind
```

### Why External Lag Monitoring?

**Consumer client provides records-lag-max:**

```
Problems with client-side lag metric:
  1. Shows only worst partition (not overall picture)
  2. Requires consumer to be running
  3. Consumer calculates it (subjective)

Consumer broken:
  records-lag-max: (not available)
  Actual lag: Growing rapidly!

Result: Metric unavailable when you need it most
```

**Better approach: External monitoring**

```
External Monitor (independent of consumer):
  1. Query broker for partition log-end-offset
  2. Query broker for consumer group committed offset
  3. Calculate lag = log-end-offset - committed-offset
  4. Repeat for all partitions
  5. Alert based on objective measurements
```

### Lag Monitoring Challenges

**Multi-partition complexity:**
```
Large consumer (e.g., MirrorMaker):
  - 1,500 topics
  - Average 20 partitions per topic
  - Total: 30,000 partitions to monitor

Challenges:
  - Different topics have different "normal" lag
  - Setting thresholds for 30,000 metrics is impractical
  - Need aggregate view of consumer health
```

**Different traffic patterns:**
```
High-traffic topic:
  Normal lag: < 100 messages
  Alert threshold: > 1,000 messages

Low-traffic topic:
  Normal lag: 0-5 messages
  Alert threshold: > 50 messages

Setting thresholds for each is impractical at scale
```

### Burrow: Intelligent Lag Monitoring

**In plain English:** Burrow watches consumer progress patterns instead of absolute lag numbers—like judging if a car is moving, not how far behind it is.

**Traditional monitoring:**
```
Lag threshold alert:
  If lag > 10,000 messages → Alert

Problems:
  - Different per topic
  - False alerts on slow topics
  - Missed problems on fast topics
```

**Burrow approach:**
```
Monitor lag progression over time:

Healthy consumer:
  Time:  0s    10s   20s   30s
  Lag:   100   50    25    10   (decreasing ✓)

Falling behind:
  Time:  0s    10s    20s    30s
  Lag:   100   500   1200   2000 (increasing ✗)

Stalled:
  Time:  0s    10s   20s   30s
  Lag:   500   500   500   500  (not changing ✗)
```

**Burrow features:**
- No thresholds required (pattern-based)
- Single status per consumer group (simple alerting)
- Multi-cluster support
- HTTP API for integration
- Absolute lag still available if needed

**Status values:**
```
OK:         Consumer keeping up
WARNING:    Consumer falling behind
ERROR:      Consumer stalled or stopped
```

> **💡 Insight**
>
> Absolute lag is misleading—a consumer 1,000 messages behind but catching up is healthier than one 100 messages behind but stalling. Burrow monitors the trend, not the number.

**Deployment:** Open source application by LinkedIn, easy integration with existing monitoring

---

## 10. End-to-End Monitoring

**In plain English:** Brokers say "I'm working fine," but can clients actually produce and consume? External monitoring provides objective proof.

### The Problem with Internal Metrics

```
Broker perspective:
  CPU: ✓ Normal
  Disk: ✓ Normal
  Network: ✓ Normal
  All metrics: ✓ Healthy

Client perspective:
  Cannot connect to broker
  Network path blocked by firewall
  Clients failing → Users impacted

Internal metrics: "Everything is fine"
Reality: Service is down
```

### The External Monitoring Solution

**Key questions to answer:**
- Can I produce messages to the Kafka cluster?
- Can I consume messages from the Kafka cluster?
- What is the end-to-end latency (produce → consume)?

### Xinfra Monitor (Kafka Monitor)

**How it works:**
```
1. Create monitoring topic across all brokers
2. Continuously produce messages to topic
3. Continuously consume messages from topic
4. Measure:
   - Produce availability (success rate)
   - Consume availability (success rate)
   - End-to-end latency (produce to consume)
```

**Architecture:**
```
Xinfra Monitor (external to cluster)
        ↓
    [Producer] → Broker 1
                 Broker 2 → [Consumer]
                 Broker 3
                 Broker 4
        ↑             ↓
    Metrics:     Metrics:
    - Produce availability
    - Produce latency
    - Consume availability
    - End-to-end latency
```

**Advantages:**
- Objective client perspective
- Per-broker visibility
- Catches problems invisible to broker metrics
- Synthetic traffic (no impact on real workloads)

**Use case example:**
```
Problem: Network ACL change blocks client traffic

Broker metrics:
  All normal (brokers can't see the problem)

Xinfra Monitor:
  Produce availability: 0% 🚨
  Alert fires immediately

Root cause: Network team made firewall change
Resolution: Revert ACL change
```

> **💡 Insight**
>
> Internal metrics are subjective (Kafka's opinion). External synthetic monitoring is objective (customer experience). Both are necessary for complete visibility.

**Deployment:** Open source by LinkedIn, supports multi-cluster monitoring

---

## 11. Summary

Monitoring Apache Kafka requires a multi-layered approach:

### Key Takeaways

**1. Metric sources form a hierarchy of objectivity:**
```
Most objective:    Client metrics, synthetic monitors
More objective:    Infrastructure metrics
Less objective:    Kafka broker metrics
Least objective:   Application logs
```

**2. Service-Level Objectives drive effective alerting:**
```
Traditional:       Alert on individual metrics (noisy)
Modern:            Alert on SLO burn rate (customer-focused)

Result: Fewer, more meaningful alerts
```

**3. Critical broker metrics:**
```
Essential monitoring:
  - Under-replicated partitions (diagnostic, not alerting)
  - Active controller count (must be exactly 1)
  - Request handler idle ratio (> 20%)
  - Offline partitions count (must be 0)

Growth/capacity planning:
  - All topics bytes in/out
  - Partition and leader counts
  - Request latencies (99.9th percentile)
```

**4. JVM and OS monitoring are essential:**
```
JVM:
  - Garbage collection frequency and duration
  - File descriptor usage

OS:
  - CPU load average
  - Disk I/O performance (most critical!)
  - Network throughput
  - Memory/swap usage
```

**5. Client monitoring complements broker monitoring:**
```
Producer:
  - record-error-rate (must be 0)
  - request-latency-avg (establish baseline)

Consumer:
  - Use external lag monitoring (Burrow)
  - Monitor coordinator sync activity
  - Track throttle time (quota enforcement)
```

**6. External monitoring provides objectivity:**
```
Burrow:          Consumer lag monitoring without thresholds
Xinfra Monitor:  End-to-end availability and latency
```

### The Monitoring Pyramid

```
                    🎯 SLO Alerts
                    (Customer impact)
                         ↑
                  External Monitors
                 (Burrow, Xinfra)
                         ↑
                  Client Metrics
              (Producer, Consumer JMX)
                         ↑
                  Broker Metrics
            (Kafka JMX, request timing)
                         ↑
                  Infrastructure
           (OS, JVM, network, disk)
```

### Final Recommendations

**Start simple:**
1. External health checks
2. SLO-based alerting (if possible)
3. Critical broker metrics (5-10 metrics)
4. OS resource monitoring

**Expand gradually:**
1. Add client monitoring
2. Implement external lag monitoring (Burrow)
3. Add end-to-end monitoring (Xinfra Monitor)
4. Deep-dive metrics for debugging (per-topic, per-partition)

**Avoid these traps:**
- Alert fatigue from too many metrics
- URP as primary alert (too noisy)
- Ignoring external/objective monitoring
- Collecting metrics without using them

> **💡 Insight**
>
> Good monitoring is not about collecting the most metrics—it's about collecting the right metrics and responding to them effectively. Start with customer impact (SLOs) and work backward to root causes.

**Remember:** The goal is not comprehensive metrics—it's reliable Kafka clusters and satisfied users.

---

**Previous:** [Chapter 12: Administering Kafka](./chapter12.md) | **Next:** [Chapter 14: Stream Processing](./chapter14.md)
