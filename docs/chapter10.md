# 10. Cross-Cluster Data Mirroring

> **In plain English:** Cross-cluster mirroring is like having multiple post offices in different cities that automatically copy letters between them—keeping important messages synchronized across locations for backup and faster local access.
>
> **In technical terms:** Cross-cluster data mirroring is the process of continuously copying data between independent Kafka clusters to support disaster recovery, geographic distribution, and data aggregation use cases.
>
> **Why it matters:** Modern businesses operate globally and need data available in multiple locations for resilience, compliance, and performance. Mirroring ensures your data is where you need it, when you need it.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Use Cases of Cross-Cluster Mirroring](#2-use-cases-of-cross-cluster-mirroring)
   - 2.1. [Regional and Central Clusters](#21-regional-and-central-clusters)
   - 2.2. [High Availability and Disaster Recovery](#22-high-availability-and-disaster-recovery)
   - 2.3. [Regulatory Compliance](#23-regulatory-compliance)
   - 2.4. [Cloud Migrations](#24-cloud-migrations)
   - 2.5. [Aggregation of Data from Edge Clusters](#25-aggregation-of-data-from-edge-clusters)
3. [Multicluster Architectures](#3-multicluster-architectures)
   - 3.1. [Realities of Cross-Datacenter Communication](#31-realities-of-cross-datacenter-communication)
   - 3.2. [Hub-and-Spoke Architecture](#32-hub-and-spoke-architecture)
   - 3.3. [Active-Active Architecture](#33-active-active-architecture)
   - 3.4. [Active-Standby Architecture](#34-active-standby-architecture)
   - 3.5. [Stretch Clusters](#35-stretch-clusters)
4. [Apache Kafka's MirrorMaker](#4-apache-kafkas-mirrormaker)
   - 4.1. [Configuring MirrorMaker](#41-configuring-mirrormaker)
   - 4.2. [Securing MirrorMaker](#42-securing-mirrormaker)
   - 4.3. [Deploying in Production](#43-deploying-in-production)
   - 4.4. [Tuning MirrorMaker](#44-tuning-mirrormaker)
5. [Other Cross-Cluster Solutions](#5-other-cross-cluster-solutions)
   - 5.1. [Uber uReplicator](#51-uber-ureplicator)
   - 5.2. [LinkedIn Brooklin](#52-linkedin-brooklin)
   - 5.3. [Confluent Solutions](#53-confluent-solutions)
6. [Summary](#6-summary)

---

## 1. Introduction

For most of this book, we've discussed managing a single Kafka cluster. But what happens when your business needs span multiple locations, regions, or even continents?

**In plain English:** Think of running multiple Kafka clusters like operating chain stores in different cities. Sometimes each store operates independently. Other times, they need to share inventory data, sales reports, or customer information between locations.

### When One Cluster Isn't Enough

There are two basic scenarios for running multiple Kafka clusters:

**Completely Separated Clusters:**
- Different departments or use cases
- No need to share data
- Different SLAs or workloads
- Different security requirements

Managing these is simple—you run each cluster independently.

**Interdependent Clusters:**
- Need continuous data copying between clusters
- Require cross-cluster mirroring
- Share critical business data

> **💡 Insight**
>
> In databases, we call continuously copying data "replication." In Kafka, we already use that term for copying data between brokers in the same cluster. So for cross-cluster copying, we use the term **mirroring** instead.

---

## 2. Use Cases of Cross-Cluster Mirroring

Let's explore the most common scenarios that require mirroring data between Kafka clusters.

### 2.1. Regional and Central Clusters

**The Scenario:**
```
Regional Datacenters          Central Datacenter
─────────────────────         ──────────────────
NYC Cluster (local)    ──┐
SF Cluster (local)     ──┼──→  Central Cluster
London Cluster (local) ──┘     (analytics)
```

**In plain English:** Like regional offices sending daily reports to headquarters—local operations run independently, but central management needs the complete picture.

**Example:** A company adjusts prices based on local supply and demand:
- Each city has a datacenter collecting local data
- Prices adjust based on regional conditions
- All data mirrors to a central cluster
- Business analysts run company-wide reports

### 2.2. High Availability and Disaster Recovery

**The Scenario:**
```
Primary Cluster        Standby Cluster
───────────────        ───────────────
Active 24/7     ────→  Ready for failover
All operations         Contains all data
                       Used if primary fails
```

**In plain English:** Like having a backup generator—you hope you never need it, but it's there if the main power fails.

**Key Points:**
- Applications use only the primary cluster normally
- Secondary cluster stays ready for emergencies
- Can switch applications to secondary if needed
- Often required by regulations, not just preference

### 2.3. Regulatory Compliance

**The Scenario:** Different countries have different data laws:
- Some data must stay in specific regions
- Different retention periods by location
- Strict access controls on sensitive data
- Subsets of data can be replicated elsewhere

**In plain English:** Like filing cabinets with different locks—some documents stay in secure locations, while copies of approved documents can be shared more widely.

### 2.4. Cloud Migrations

**The Scenario:**
```
On-Premises          Cloud Provider
───────────          ──────────────
Legacy Apps    ─┐
Databases      ─┼─→  Cloud Apps
                │    Need on-prem data
                └─→  Multiple regions
```

**In plain English:** Like moving your business from a physical office to remote work—some people work from the old office, some from home, but everyone needs access to the same files.

**Common Pattern:**
1. Database changes captured in on-premises Kafka
2. Changes mirrored to cloud Kafka cluster
3. Cloud applications access local data
4. Reduces cross-datacenter traffic costs

### 2.5. Aggregation of Data from Edge Clusters

**The Scenario:**
```
Edge Devices              Central Analytics
────────────              ─────────────────
IoT sensors      ──┐
Retail stores    ──┤
Manufacturing    ──┼──→   Aggregate Cluster
Hospitals        ──┤      (high availability)
Mobile devices   ──┘
```

**In plain English:** Like collecting weather data from thousands of small sensors into one central weather station for forecasting.

**Benefits:**
- Edge clusters can be simple and lightweight
- Limited connectivity requirements at the edge
- Central cluster provides business continuity
- Analytics don't deal with unstable networks

> **💡 Insight**
>
> Each use case represents a different trade-off between data locality, availability, and consistency. The architecture you choose should match your specific business requirements.

---

## 3. Multicluster Architectures

Before diving into specific patterns, let's understand the networking realities that shape our architectural decisions.

### 3.1. Realities of Cross-Datacenter Communication

**The Challenges:**

**High Latency**
```
Same Datacenter:     1-5 ms
Cross-Datacenter:    50-200 ms
Cross-Continent:     200-500 ms
```

**Limited Bandwidth**
- WANs have far less bandwidth than local networks
- Higher latency makes utilizing bandwidth harder
- Available bandwidth varies minute to minute

**Higher Costs**
- Adding bandwidth is expensive
- Cloud providers charge for data transfer
- Costs multiply with traffic volume

> **💡 Insight**
>
> Kafka was designed for low latency and high bandwidth within a single datacenter. Splitting brokers across datacenters is not recommended except in specific cases like stretch clusters.

**Three Guiding Principles:**

1. **No less than one cluster per datacenter**
   - Don't split a single cluster across datacenters

2. **Replicate each event exactly once**
   - Between each pair of datacenters
   - Avoid unnecessary duplicate traffic

3. **Consume from remote, not produce to remote**
   - Safer in case of network partitions
   - Records stay safe in brokers if consumer fails

### 3.2. Hub-and-Spoke Architecture

**The Pattern:**
```
Regional Clusters     Central Hub
─────────────────     ───────────
NYC Cluster    ──┐
SF Cluster     ──┼──→  Central
London Cluster ──┘     Cluster
```

**In plain English:** Like a bicycle wheel—spokes (regional clusters) connect to the hub (central cluster), but spokes don't connect to each other.

**When to Use:**
- Multiple regional datacenters
- One central location for analytics
- Applications only need local data OR complete dataset

**Benefits:**
- Simple to deploy and configure
- Data always produced locally (low latency)
- Each event mirrored only once
- Easy to monitor

**Limitations:**
- Regional clusters can't access each other's data
- Users must stay in their region

**Example Problem:**
```
Scenario: Bank with branches in multiple cities
Problem:  Customer visits branch in different city
Issue:    User data only exists in home city
Result:   Branch can't access customer information
```

**Implementation:**
- One mirroring process per regional cluster
- All processes run in the central datacenter
- Events from same topic can merge or stay separate

### 3.3. Active-Active Architecture

**The Pattern:**
```
Datacenter A          Datacenter B
────────────          ────────────
Read/Write     ←──→   Read/Write
All topics            All topics
Serves users          Serves users
```

**In plain English:** Like two stores with the same inventory system—both can sell products and update stock, but they need to sync constantly to avoid conflicts.

**When to Use:**
- Need to serve users from multiple locations
- Want redundancy and resilience
- Can handle complexity of conflicts

**Benefits:**
- Users get nearby datacenter (lower latency)
- Redundancy—if one fails, use the other
- Network failover is easy and transparent

**Challenges:**

**1. Avoiding Replication Loops**
```
Solution: Use datacenter prefixes
NYC datacenter writes to: NYC.users
SF datacenter writes to:  SF.users

Each datacenter has both topics
Consumers read from: *.users
```

**2. Managing Conflicts**
```
User adds book to wishlist in NYC
User views wishlist in London (data not synced yet)
Result: Book appears missing
```

**Solution:** "Sticky" users to specific datacenters when possible

**3. Concurrent Updates**
```
NYC: User orders book A at 10:00:00
SF:  User orders book B at 10:00:01
Both events eventually reach both datacenters
```

**Solutions:**
- Pick one event as "correct" (need consistent rules)
- Accept both events (send two books, handle returns)
- Use application-specific conflict resolution

> **💡 Insight**
>
> Active-active is the most scalable and cost-effective option, but requires careful design for conflict handling. If you can solve the conflict challenges, it's highly recommended.

### 3.4. Active-Standby Architecture

**The Pattern:**
```
Primary Cluster       Standby Cluster
───────────────       ───────────────
Active 24/7    ────→  Receives all data
Serves apps           Waits for disaster
                      "Cold" applications
```

**In plain English:** Like a spare tire—it's there for emergencies, but you don't use it unless you have to.

**When to Use:**
- Need disaster recovery capability
- Legal requirements for backups
- Don't need data from multiple locations

**Benefits:**
- Simple setup—just mirror everything
- Works for any use case
- One-way data flow

**Disadvantages:**

**1. Wasted Resources**
- Cluster sits idle most of the time
- Can use smaller DR cluster (risky)
- Can shift read-only workloads to DR

**2. Failover Challenges**
```
Problem: Kafka failover loses data OR creates duplicates
Reason:  Asynchronous mirroring always has lag
```

**Failover Considerations:**

**Recovery Time Objective (RTO)**
- Maximum time before services resume
- Lower RTO needs automated failover

**Recovery Point Objective (RPO)**
- Maximum acceptable data loss
- Low RPO needs low-latency mirroring
- RPO=0 requires synchronous replication

**Data Loss in Failover:**
```
Primary cluster: 1,000,000 requests/week
Lag: 5 milliseconds
Expected loss: 5,000 messages on failover
```

**Offset Management After Failover:**

**Option 1: Auto Offset Reset**
```
Simple but crude:
- Start from beginning (many duplicates)
- Skip to end (miss some data)
```

**Option 2: Replicate Offsets Topic**
```
Mirror __consumer_offsets topic
Issues:
- Offsets may not match between clusters
- Retries can cause divergence
- Commits may arrive before/after records
```

**Option 3: Time-Based Failover**
```
Disaster at 4:05 AM
Failover to 4:03 AM

Command:
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --reset-offsets --all-topics --group my-group \
  --to-datetime 2021-03-31T04:03:00.000 --execute
```

**Option 4: Offset Translation**
```
Store mapping: Primary offset → DR offset
Example: (495,500), (596,600)
Use mapping during failover
```

> **💡 Insight**
>
> Practice failover regularly—quarterly at minimum, more frequently if possible. Netflix's Chaos Monkey randomly causes disasters, making every day potential practice.

**After Failover:**
```
Options:
1. Reverse mirroring direction (complex, risky)
2. Scrape original cluster (safest)
   - Delete all data and offsets
   - Start fresh mirroring from new primary
   - Ensures consistency
```

### 3.5. Stretch Clusters

**The Pattern:**
```
Single Kafka Cluster Spanning Multiple Datacenters
───────────────────────────────────────────────────
Datacenter A     Datacenter B     Datacenter C
Broker 1,2,3     Broker 4,5,6     ZooKeeper node
```

**In plain English:** Like one company with offices in three buildings on the same street—it's all one organization, just physically distributed.

**Key Differences:**
- **One cluster**, not multiple
- Uses Kafka's normal replication
- Can use synchronous replication
- No mirroring process needed

**Requirements:**
- At least three datacenters
- High bandwidth between them
- Low latency (<50ms)
- Typically: 3 availability zones in one cloud region

**Configuration:**
```
Use rack definitions for replica placement
Use min.insync.replicas with acks=all
Consumers can fetch from closest replica
Synchronous writes to multiple datacenters
```

**Benefits:**
- Synchronous replication (100% sync)
- Both/all datacenters actively used
- No waste like active-standby

**Limitations:**
- Only protects against datacenter failure
- Doesn't protect against app/Kafka bugs
- Requires specific infrastructure

**Why Three Datacenters?**
```
ZooKeeper needs odd number of nodes
Needs majority to stay available

Two datacenters:
- One always has majority
- If that one fails → ZooKeeper fails

Three datacenters:
- No single datacenter has majority
- One can fail, others maintain quorum
```

**2.5 DC Architecture:**
```
Two full datacenters + 0.5 datacenter
Datacenter A: Kafka + ZooKeeper
Datacenter B: Kafka + ZooKeeper
Datacenter C: One ZooKeeper node (provides quorum)
```

---

## 4. Apache Kafka's MirrorMaker

MirrorMaker is Kafka's built-in tool for cross-cluster data mirroring.

**Evolution:**
```
Legacy MirrorMaker:
- Simple consumer group + shared producer
- Had latency spikes during rebalances
- Stop-the-world for configuration changes

MirrorMaker 2.0 (Kafka 2.4+):
- Based on Kafka Connect framework
- Overcomes legacy limitations
- Supports complex topologies
```

**Architecture:**
```
Source Cluster          Target Cluster
──────────────          ──────────────
Topics          ─────→  Connect Workers
                        ├─ Source Connector
                        ├─ Tasks (consumer+producer pairs)
                        └─ Target Topics
```

### 4.1. Configuring MirrorMaker

**Basic Setup:**

```bash
bin/connect-mirror-maker.sh etc/kafka/connect-mirror-maker.properties
```

**Active-Standby Example:**

```properties
# Define cluster aliases
clusters = NYC, LON

# Configure bootstrap servers
NYC.bootstrap.servers = kafka.nyc.example.com:9092
LON.bootstrap.servers = kafka.lon.example.com:9092

# Enable replication flow
NYC->LON.enabled = true

# Configure topics to mirror
NYC->LON.topics = .*
```

**Key Configuration Options:**

**1. Replication Flow**
```properties
clusters = NYC, LON, SF
NYC->LON.enabled = true    # NYC to London
NYC->SF.enabled = true     # NYC to SF
```

**2. Topic Selection**
```properties
NYC->LON.topics = prod.*           # Regex pattern
NYC->LON.topics.exclude = test.*   # Exclusion pattern
```

**Default Naming:**
```
Source topic: orders
Target topic: NYC.orders (prefixed with cluster alias)
```

**Benefits of Prefixing:**
- Prevents replication loops in active-active
- Distinguishes local vs remote topics
- Supports aggregation use cases

**3. Consumer Offset Migration**

```properties
# Automatically migrate offsets (Kafka 2.7+)
sync.group.offsets.enabled = true
sync.group.offsets.interval.seconds = 60
```

**Failover Support:**
```java
// Use RemoteClusterUtils to seek to checkpointed offset
import org.apache.kafka.connect.mirror.RemoteClusterUtils;

// Consumers can restart from last offset on failover
// Minimal data loss and duplicate processing
```

**4. Configuration and ACL Migration**

```properties
# Topic configuration migration (default: enabled)
sync.topic.configs.enabled = true

# ACL migration (default: enabled)
sync.topic.acls.enabled = true
```

**Notes:**
- Most topic configs migrated
- Some like `min.insync.replicas` excluded
- Only literal topic ACLs migrated
- Write ACLs not migrated (security)

**5. Connector Tasks**

```properties
# Increase for better parallelism
tasks.max = 4

# Minimum recommended: 2
# Higher for many partitions
```

**6. Configuration Prefixes**

```properties
# Hierarchy (most specific wins):
{cluster}.{connector_config}
{cluster}.admin.{admin_config}
{source_cluster}.consumer.{consumer_config}
{target_cluster}.producer.{producer_config}
{source_cluster}->{target_cluster}.{replication_flow_config}
```

**Active-Active Configuration:**

```properties
clusters = NYC, LON
NYC.bootstrap.servers = kafka.nyc.example.com:9092
LON.bootstrap.servers = kafka.lon.example.com:9092

# Bidirectional replication
NYC->LON.enabled = true
NYC->LON.topics = .*

LON->NYC.enabled = true
LON->NYC.topics = .*
```

**Hub-and-Spoke Configuration:**

```properties
clusters = NYC, LON, SF
SF.bootstrap.servers = kafka.sf.example.com:9092

# Fan-out from NYC
NYC->SF.enabled = true
NYC->SF.topics = .*
```

### 4.2. Securing MirrorMaker

**Enable SSL Encryption:**

```properties
# NYC cluster security
NYC.security.protocol = SASL_SSL
NYC.sasl.mechanism = PLAIN
NYC.sasl.jaas.config = org.apache.kafka.common.security.plain.PlainLoginModule \
  required username="MirrorMaker" password="MirrorMaker-password";
```

**Required ACLs for MirrorMaker:**

```
Source Cluster:
- Topic:Read on source topics
- Topic:DescribeConfigs for topic configuration
- Group:Describe for consumer group metadata
- Cluster:Describe for topic ACLs

Target Cluster:
- Topic:Create and Topic:Write for target topics
- Topic:AlterConfigs to update configuration
- Topic:Alter to add partitions
- Group:Read to commit offsets
- Cluster:Alter to update ACLs
```

### 4.3. Deploying in Production

**Deployment Modes:**

**1. Dedicated Mode (Recommended)**
```bash
# Start MirrorMaker as standalone service
bin/connect-mirror-maker.sh mm2.properties -daemon

# Start multiple instances for fault tolerance
# Instances auto-discover and load balance
```

**2. Distributed Connect Mode**
```
Run in existing Connect cluster
Share infrastructure with other connectors
Configure connectors via REST API
```

**Best Practices:**

**Location: Run at Target Datacenter**
```
Safer to consume remotely than produce remotely

If network partition occurs:
- Consumer can't connect → Events safe in source
- Producer can't connect → Risk of losing events
```

**Exception: Encryption Requirements**
```
If cross-datacenter needs SSL but local doesn't:
- Run MirrorMaker at source
- Consume locally (unencrypted, fast)
- Produce remotely (encrypted, slower)
- Producer SSL has less performance impact
```

**Exception: Firewall Restrictions**
```
On-premises to cloud:
- Firewall blocks incoming from cloud
- Run MirrorMaker on-premises
- All connections go outbound to cloud
```

**Monitoring:**

**1. Kafka Connect Metrics**
```
- Connector status
- Source connector throughput
- Worker rebalance delays
- REST API for management
```

**2. MirrorMaker-Specific Metrics**
```
replication-latency-ms:     Time from record creation to target
record-age-ms:              Age of records at replication
byte-rate:                  Replication throughput
checkpoint-latency-ms:      Offset migration latency
```

**3. Lag Monitoring**
```
Source cluster last offset:  7
Target cluster last offset:  5
Lag: 2 messages

Methods:
- Check MirrorMaker committed offsets (updated every minute)
- Check consumer maximum lag metric (not 100% accurate)
```

**Visualization:**
```
Source: [1][2][3][4][5][6][7]
Target: [1][2][3][4][5]
                      ↑
                    Lag = 2
```

> **💡 Insight**
>
> Neither lag measurement method is perfect. The committed offset shows lag as of last commit (may be stale). The consumer lag doesn't account for producer send failures. Use multiple monitoring methods.

### 4.4. Tuning MirrorMaker

**Sizing Strategy:**

```
Goal: Size for 75-80% utilization 95-99% of time

If peak throughput is critical:
- Size for 100% of peak
- More expensive but no lag

If some lag acceptable:
- Size for 75-80% average
- Lag during peaks
- Catches up during normal load
```

**Performance Testing:**

```bash
# Generate test load
kafka-performance-producer \
  --topic test-topic \
  --num-records 1000000 \
  --throughput 10000

# Test with different task counts
tasks.max = 1, 2, 4, 8, 16, 24, 32

# Watch for:
- Throughput plateau
- CPU utilization
- Network saturation
```

**Compression Impact:**
```
MirrorMaker must:
1. Decompress events from source
2. Recompress for target
3. Uses significant CPU

Monitor CPU usage when increasing tasks
```

**Network Tuning:**

**TCP Buffer Sizes:**
```properties
# Producer/Consumer settings
send.buffer.bytes = 131072
receive.buffer.bytes = 131072

# Broker settings
socket.send.buffer.bytes = 102400
socket.receive.buffer.bytes = 102400
```

**Linux Network Configuration:**
```bash
# Increase TCP buffer sizes
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.optmem_max = 40960

# Enable TCP window scaling
sysctl -w net.ipv4.tcp_window_scaling=1

# Reduce TCP slow start
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle
```

**Producer Tuning:**

**Increase Batch Sizes:**
```properties
linger.ms = 10                    # Wait to fill batches
batch.size = 32768                # Larger batches
```

**Increase Parallelism:**
```properties
max.in.flight.requests.per.connection = 5

# Trade-off:
# Higher = Better throughput
# Lower (1) = Preserve message order
```

**Consumer Tuning:**

**Fetch Larger Amounts:**
```properties
fetch.max.bytes = 52428800        # 50 MB
fetch.min.bytes = 1024            # 1 KB minimum
fetch.max.wait.ms = 500           # Wait for batches
```

**Topic Separation:**
```
Separate sensitive topics to dedicated MirrorMaker cluster

Benefits:
- Prevent one topic from slowing others
- Isolate critical data pipelines
- Better performance guarantees
```

---

## 5. Other Cross-Cluster Solutions

### 5.1. Uber uReplicator

**Problem:** Legacy MirrorMaker at scale
```
Issues:
- Long rebalances (5-10 minutes)
- Stops all consumers during rebalance
- Many topics/partitions = long pauses
- Topic additions trigger rebalances
```

**Solution:** Apache Helix for coordination
```
Architecture:
- Helix controller manages topic list
- REST API for adding topics
- Custom Helix consumer (no rebalancing)
- Partitions assigned by controller
- Changes happen without pausing
```

**Trade-offs:**
- Requires Apache Helix (added complexity)
- MirrorMaker 2.0 solves similar issues
- No external dependencies in MM2

### 5.2. LinkedIn Brooklin

**Overview:** Generic data streaming framework
```
Capabilities:
- Stream data between heterogeneous systems
- Change data capture from databases
- Cross-cluster Kafka mirroring
- Scalable and reliable at LinkedIn scale
```

**Scale:**
```
Processes trillions of messages per day
Optimized for:
- Stability
- Performance
- Operability
```

**Features:**
- REST API for management
- Shared service for multiple pipelines
- Mirrors data across multiple Kafka clusters

### 5.3. Confluent Solutions

**Confluent Replicator**
```
Features:
- Kafka Connect-based
- Topic and config migration
- Offset translation (Java clients only)
- Provenance headers (avoid loops)
- Schema migration and translation
```

**Multi-Region Clusters (MRC)**
```
Use case: < 50ms latency datacenters
Features:
- Synchronous + asynchronous replication
- Observers (async replicas, not in ISR)
- Automatic observer promotion on failure
- Consumers fetch from closest replica
```

**Cluster Linking**
```
Use case: Distant datacenters
Features:
- Built into Confluent Server
- Offset-preserving replication
- Syncs topics, configs, offsets, ACLs
- No external dependencies
- Better performance (no decompress/recompress)
- Manual failover required
```

---

## 6. Summary

**Key Takeaways:**

**1. Use Cases Drive Architecture**
```
Disaster Recovery    → Active-Standby or Stretch
Global Distribution  → Active-Active or Hub-and-Spoke
Compliance          → Separate clusters with mirroring
Cloud Migration     → Temporary bridging between environments
```

**2. Architecture Trade-offs**
```
Active-Active:   Most scalable, handles conflicts
Active-Standby:  Simplest, wastes resources
Hub-and-Spoke:   Easy to manage, limited data access
Stretch Clusters: Best sync, infrastructure requirements
```

**3. MirrorMaker 2.0 Capabilities**
```
✓ Complex topologies support
✓ Offset migration
✓ Config and ACL migration
✓ Kafka Connect framework
✓ Prevents replication loops
```

**4. Production Considerations**
```
- Run MirrorMaker at target datacenter
- Monitor lag, latency, and throughput
- Practice failover regularly
- Secure all cross-datacenter traffic
- Tune network and Kafka clients
```

**5. Beyond MirrorMaker**
```
Consider alternatives for:
- Very large scale (uReplicator, Brooklin)
- Commercial support (Confluent solutions)
- Specific requirements (offset preservation, etc.)
```

> **💡 Insight**
>
> Treat multicluster management seriously. Don't treat it as an afterthought. Apply proper design, testing, deployment automation, monitoring, and maintenance—just like any production system. Success requires a holistic disaster recovery plan involving multiple applications and data stores.

---

**Previous:** [Chapter 9: Building Data Pipelines](./chapter9.md) | **Next:** [Chapter 11: Securing Kafka →](./chapter11.md)
