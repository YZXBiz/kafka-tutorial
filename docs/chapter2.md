# 2. Installing Kafka

> **In plain English:** Installing Kafka is like setting up a post office - you need the building (ZooKeeper), the sorting system (Kafka broker), and proper infrastructure (Java, disk, network) before you can start handling mail.
>
> **In technical terms:** Kafka installation involves setting up dependencies (Java, ZooKeeper), configuring broker parameters, selecting appropriate hardware, and establishing cluster configurations for production readiness.
>
> **Why it matters:** A properly configured Kafka installation is the foundation for reliable, high-performance message streaming. Poor setup choices compound into performance bottlenecks and maintenance headaches as your system scales.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Environment Setup](#2-environment-setup)
   - 2.1. [Choosing an Operating System](#21-choosing-an-operating-system)
   - 2.2. [Installing Java](#22-installing-java)
3. [Installing ZooKeeper](#3-installing-zookeeper)
   - 3.1. [Understanding ZooKeeper's Role](#31-understanding-zookeepers-role)
   - 3.2. [Standalone Server](#32-standalone-server)
   - 3.3. [ZooKeeper Ensemble](#33-zookeeper-ensemble)
4. [Installing a Kafka Broker](#4-installing-a-kafka-broker)
   - 4.1. [Basic Installation](#41-basic-installation)
   - 4.2. [Verification and Testing](#42-verification-and-testing)
5. [Configuring the Broker](#5-configuring-the-broker)
   - 5.1. [General Broker Parameters](#51-general-broker-parameters)
   - 5.2. [Topic Defaults](#52-topic-defaults)
6. [Selecting Hardware](#6-selecting-hardware)
   - 6.1. [Disk Throughput](#61-disk-throughput)
   - 6.2. [Disk Capacity](#62-disk-capacity)
   - 6.3. [Memory](#63-memory)
   - 6.4. [Networking](#64-networking)
   - 6.5. [CPU](#65-cpu)
7. [Kafka in the Cloud](#7-kafka-in-the-cloud)
   - 7.1. [Microsoft Azure](#71-microsoft-azure)
   - 7.2. [Amazon Web Services](#72-amazon-web-services)
8. [Configuring Kafka Clusters](#8-configuring-kafka-clusters)
   - 8.1. [How Many Brokers?](#81-how-many-brokers)
   - 8.2. [Broker Configuration](#82-broker-configuration)
9. [OS Tuning](#9-os-tuning)
   - 9.1. [Virtual Memory](#91-virtual-memory)
   - 9.2. [Disk](#92-disk)
   - 9.3. [Networking](#93-networking)
10. [Production Concerns](#10-production-concerns)
    - 10.1. [Garbage Collector Options](#101-garbage-collector-options)
    - 10.2. [Datacenter Layout](#102-datacenter-layout)
    - 10.3. [Colocating Applications on ZooKeeper](#103-colocating-applications-on-zookeeper)
11. [Summary](#11-summary)

---

## 1. Introduction

Getting Apache Kafka up and running involves more than just downloading a binary. This chapter guides you through the complete setup process: from preparing your environment to configuring production clusters that can handle millions of messages per second.

**In plain English:** Think of this chapter as your construction manual - we'll build from the foundation (operating system and Java) up through the infrastructure (ZooKeeper and Kafka), and finish with production-grade optimizations.

> **💡 Insight**
>
> Installation choices you make today will impact your system's performance, scalability, and operational complexity for years. Take time to understand the trade-offs rather than accepting defaults blindly.

We'll cover:
- Setting up ZooKeeper for metadata storage
- Installing and configuring Kafka brokers
- Selecting appropriate hardware
- Tuning operating systems for optimal performance
- Production deployment best practices

---

## 2. Environment Setup

Before running Apache Kafka, your environment needs proper prerequisites. This ensures Kafka runs reliably and performs optimally.

### 2.1. Choosing an Operating System

**In plain English:** While Kafka can run on Windows, macOS, or Linux, Linux is like a race car's natural habitat - it's where Kafka performs best.

Apache Kafka is a Java application that runs on many operating systems. However, **Linux is the recommended OS** for production use cases due to:
- Better performance characteristics
- Superior process isolation
- More mature tooling ecosystem
- Extensive production battle-testing

**The installation steps in this chapter focus on Linux environments.** For Windows and macOS installation instructions, see Appendix A.

> **💡 Insight**
>
> Your OS choice affects more than just Kafka - it impacts monitoring tools, deployment scripts, and operational runbooks. Standardizing on Linux simplifies your entire operational stack.

### 2.2. Installing Java

**Before installing ZooKeeper or Kafka, you need a functioning Java environment.**

**In plain English:** Java is the engine that runs Kafka - like how you need electricity before plugging in appliances.

**Requirements:**
- **Supported versions**: Java 8 or Java 11
- **Compatible implementations**: All OpenJDK-based implementations (including Oracle JDK)
- **Recommended**: Java Development Kit (JDK) rather than just the runtime edition

**Security consideration:** Install the latest released patch version to avoid security vulnerabilities in older versions.

**Example setup:**
This book assumes JDK version 11 update 10 installed at `/usr/java/jdk-11.0.10`.

```bash
# Verify Java installation
export JAVA_HOME=/usr/java/jdk-11.0.10
$JAVA_HOME/bin/java -version
```

> **💡 Insight**
>
> While Kafka works with runtime Java (JRE), the full JDK provides debugging tools (jmap, jstack, jstat) that become invaluable when troubleshooting production issues. Always install the complete JDK.

---

## 3. Installing ZooKeeper

### 3.1. Understanding ZooKeeper's Role

**In plain English:** If Kafka is a library system, ZooKeeper is the card catalog - it tracks where everything is, who's using what, and keeps everyone coordinated.

**What ZooKeeper does for Kafka:**
- Stores metadata about the Kafka cluster
- Tracks broker membership and health
- Maintains topic and partition assignments
- Stores consumer group details (for older consumers)
- Provides distributed coordination

**Visual representation:**
```
┌─────────────────────────────────────┐
│         ZooKeeper Ensemble          │
│  (Stores cluster metadata)          │
└──────────────┬──────────────────────┘
               │
               │ Reads/Writes
               │ metadata
               │
┌──────────────▼──────────────────────┐
│        Kafka Broker Cluster         │
│  ┌────────┐  ┌────────┐  ┌────────┐│
│  │Broker 1│  │Broker 2│  │Broker 3││
│  └────────┘  └────────┘  └────────┘│
└─────────────────────────────────────┘
```

**Technical details:**
Apache ZooKeeper is a centralized service for:
- Maintaining configuration information
- Providing distributed synchronization
- Managing group services
- Implementing naming services

**Version compatibility:** Kafka has been extensively tested with ZooKeeper 3.5 stable releases. This book uses **ZooKeeper 3.5.9**.

> **💡 Insight**
>
> ZooKeeper's importance is diminishing over time. Kafka 2.8.0 introduced early-access "ZooKeeper-less" mode. However, ZooKeeper remains essential for current production deployments and understanding legacy systems.

### 3.2. Standalone Server

A standalone ZooKeeper server works well for development and testing environments.

**Step-by-step installation:**

```bash
# Step 1: Extract and move ZooKeeper
tar -zxf apache-zookeeper-3.5.9-bin.tar.gz
mv apache-zookeeper-3.5.9-bin /usr/local/zookeeper

# Step 2: Create data directory
mkdir -p /var/lib/zookeeper

# Step 3: Create configuration file
cat > /usr/local/zookeeper/conf/zoo.cfg << EOF
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
EOF

# Step 4: Set Java environment and start
export JAVA_HOME=/usr/java/jdk-11.0.10
/usr/local/zookeeper/bin/zkServer.sh start
```

**Expected output:**
```
JMX enabled by default
Using config: /usr/local/zookeeper/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
```

**Configuration parameters explained:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `tickTime` | 2000 | Basic time unit (milliseconds) for heartbeats |
| `dataDir` | /var/lib/zookeeper | Directory where ZooKeeper stores data |
| `clientPort` | 2181 | Port for client connections |

**Verifying the installation:**

Use the four-letter command `srvr` to check ZooKeeper status:

```bash
telnet localhost 2181
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
srvr
Zookeeper version: 3.5.9-83df9301aa5c2a5d284a9940177808c01bc35cef, built on 01/06/2021 19:49 GMT
Latency min/avg/max: 0/0/0
Received: 1
Sent: 0
Connections: 1
Outstanding: 0
Zxid: 0x0
Mode: standalone
Node count: 5
Connection closed by foreign host.
```

**What to look for:**
- **Mode: standalone** - Confirms single-server operation
- **Node count: 5** - Default znodes are created
- **Version** - Confirms correct version is running

### 3.3. ZooKeeper Ensemble

**In plain English:** An ensemble is like having multiple copies of the card catalog in different buildings - if one burns down, the others keep the library running.

For production environments, ZooKeeper should run as a cluster (called an **ensemble**) to ensure high availability.

**Key principles:**

**1. Use odd numbers of servers**
```
Ensemble Size → Fault Tolerance
─────────────────────────────────
3 servers     → Survives 1 failure
5 servers     → Survives 2 failures
7 servers     → Survives 3 failures
```

**Why odd numbers?** ZooKeeper requires a **quorum** (majority) for operation:
- 3-node ensemble: Needs 2 alive (can lose 1)
- 4-node ensemble: Needs 3 alive (can lose 1) - same tolerance as 3!
- 5-node ensemble: Needs 3 alive (can lose 2)

> **💡 Insight**
>
> The quorum requirement means a 4-server ensemble provides no more fault tolerance than a 3-server ensemble, while consuming more resources. This is why odd numbers are universally recommended.

**2. Size your ensemble for maintenance**

A 5-node ensemble is recommended over 3-node for most production deployments:

```
Scenario: Rolling upgrade of 5-node ensemble
─────────────────────────────────────────────
Normal operation:   5 alive (quorum intact)
Upgrade node 1:     4 alive (quorum intact)
Unplanned failure:  3 alive (quorum intact) ✓
Continues operating!

Scenario: Rolling upgrade of 3-node ensemble
─────────────────────────────────────────────
Normal operation:   3 alive (quorum intact)
Upgrade node 1:     2 alive (quorum intact)
Unplanned failure:  1 alive (quorum LOST) ✗
Ensemble unavailable!
```

**3. Avoid ensembles larger than 7 nodes**

Performance degrades beyond 7 nodes due to the consensus protocol overhead. If experiencing load issues, add **observer nodes** instead - they serve read traffic without participating in quorum.

**Configuration example:**

For a 3-node ensemble with hosts `zoo1.example.com`, `zoo2.example.com`, and `zoo3.example.com`:

**Shared configuration file** (`zoo.cfg` on all servers):
```
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
initLimit=20
syncLimit=5
server.1=zoo1.example.com:2888:3888
server.2=zoo2.example.com:2888:3888
server.3=zoo3.example.com:2888:3888
```

**Configuration parameters explained:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `initLimit` | 20 | Time for followers to connect to leader (20 × 2000ms = 40 seconds) |
| `syncLimit` | 5 | Max time followers can be out-of-sync (5 × 2000ms = 10 seconds) |
| `server.X` | hostname:peerPort:leaderPort | Ensemble member definitions |

**Server specification format:**
```
server.X=hostname:peerPort:leaderPort
```

Where:
- **X**: Integer ID (doesn't need to be sequential, but must be unique)
- **hostname**: Hostname or IP address
- **peerPort** (2888): TCP port for inter-server communication
- **leaderPort** (3888): TCP port for leader election

**Per-server setup:**

Each server needs a unique `myid` file:

```bash
# On zoo1.example.com
echo "1" > /var/lib/zookeeper/myid

# On zoo2.example.com
echo "2" > /var/lib/zookeeper/myid

# On zoo3.example.com
echo "3" > /var/lib/zookeeper/myid
```

**Network requirements:**
- Clients only need access to `clientPort` (2181)
- Ensemble members need access to **all three ports** on each other

> **💡 Insight**
>
> Ensemble configuration looks complex but follows a pattern you'll see throughout distributed systems: each node needs a unique ID, a list of all peers, and multiple ports for different communication types (client requests vs. internal coordination).

---

## 4. Installing a Kafka Broker

### 4.1. Basic Installation

Once Java and ZooKeeper are configured, you're ready to install Apache Kafka.

**Version information:**
- This book uses Kafka **2.7.0** (built with Scala 2.13.0)
- At press time, the latest version is **2.8.0**
- Download from the [Kafka website](https://kafka.apache.org/downloads)

**Installation steps:**

```bash
# Step 1: Extract and move Kafka
tar -zxf kafka_2.13-2.7.0.tgz
mv kafka_2.13-2.7.0 /usr/local/kafka

# Step 2: Create log directory
mkdir /tmp/kafka-logs

# Step 3: Set Java environment and start broker
export JAVA_HOME=/usr/java/jdk-11.0.10
/usr/local/kafka/bin/kafka-server-start.sh -daemon \
  /usr/local/kafka/config/server.properties
```

**What's happening:**
```
Process Flow
────────────
1. Read server.properties configuration
2. Connect to ZooKeeper (default: localhost:2181)
3. Register broker in ZooKeeper
4. Create/load partition assignments
5. Start network listeners (default: port 9092)
6. Begin accepting producer/consumer connections
```

**The `-daemon` flag** runs Kafka in the background. Without it, Kafka runs in the foreground and logs to console.

### 4.2. Verification and Testing

**In plain English:** Before building on Kafka, verify it works by testing the three fundamental operations: create a topic, send messages, receive messages.

**Step 1: Create and verify a topic**

```bash
# Create topic named "test" with 1 partition and 1 replica
/usr/local/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --replication-factor 1 \
  --partitions 1 \
  --topic test

# Output:
Created topic "test".

# Verify topic details
/usr/local/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --topic test

# Output:
Topic:test    PartitionCount:1    ReplicationFactor:1    Configs:
    Topic: test    Partition: 0    Leader: 0    Replicas: 0    Isr: 0
```

**Understanding the output:**
- **Partition: 0** - First (and only) partition
- **Leader: 0** - Broker ID 0 handles this partition
- **Replicas: 0** - Partition exists on broker 0
- **Isr: 0** - In-sync replica set includes broker 0

**Step 2: Produce messages**

```bash
/usr/local/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test

# Interactive prompt appears - type messages:
Test Message 1
Test Message 2
^C  # Press Ctrl-C to exit
```

**What's happening:**
```
Your Terminal → Kafka Producer → Network → Broker → Disk
                                                    ↓
                                      /tmp/kafka-logs/test-0/
```

**Step 3: Consume messages**

```bash
/usr/local/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test \
  --from-beginning

# Output:
Test Message 1
Test Message 2
^C  # Press Ctrl-C to exit
Processed a total of 2 messages
```

**What's happening:**
```
Disk → Broker → Network → Kafka Consumer → Your Terminal
         ↑
/tmp/kafka-logs/test-0/
```

> **💡 Insight**
>
> These three operations (create, produce, consume) form the foundation of all Kafka applications. When troubleshooting complex systems, returning to these basics helps isolate whether issues are in Kafka itself or in application code.

**Important CLI change:**

Older Kafka versions used `--zookeeper` flags to connect directly to ZooKeeper. This is **deprecated**:

```bash
# Old way (deprecated):
--zookeeper localhost:2181

# New way (recommended):
--bootstrap-server localhost:9092
```

**Why the change?** Directly accessing ZooKeeper:
- Bypasses broker security controls
- Creates scaling bottlenecks
- Complicates migration to ZooKeeper-less Kafka
- Makes it harder to audit operations

Always use `--bootstrap-server` to connect to Kafka brokers directly.

---

## 5. Configuring the Broker

The example configuration shipped with Kafka works for single-broker development, but production environments require careful configuration tuning.

**In plain English:** Default settings are like a car's factory settings - they work, but you'll want to adjust them based on whether you're commuting to work or racing professionally.

This section covers essential configuration parameters. Tuning parameters for specific use cases appear in later chapters.

### 5.1. General Broker Parameters

These parameters handle basic broker setup and are essential for multi-broker clusters.

#### broker.id

**What it does:** Uniquely identifies each broker in a cluster.

**Default:** 0

**Requirements:**
- Must be an integer
- Must be unique within the cluster
- Can be any value (doesn't need to be sequential)

**Best practice:** Choose IDs that map to physical infrastructure:

```
Host Naming              →  broker.id
─────────────────────────────────────
kafka1.example.com       →  1
kafka2.example.com       →  2
kafka3.example.com       →  3

OR

kafka-us-east-01.com     →  101
kafka-us-east-02.com     →  102
kafka-us-west-01.com     →  201
```

**Why this matters:** During maintenance, you'll frequently map between broker IDs and physical hosts. Intrinsic mapping reduces operational errors.

> **💡 Insight**
>
> While technically arbitrary, broker IDs become part of your operational vocabulary. "Broker 47 is down" should immediately tell you which physical server to check. Plan your numbering scheme accordingly.

#### listeners

**What it does:** Defines the network interfaces and ports Kafka listens on.

**Format:** Comma-separated list of URIs: `<protocol>://<hostname>:<port>`

**Examples:**

```
# Listen on all interfaces, port 9092 (plaintext)
listeners=PLAINTEXT://0.0.0.0:9092

# Listen on localhost only
listeners=PLAINTEXT://localhost:9092

# Multiple listeners with different protocols
listeners=PLAINTEXT://localhost:9092,SSL://:9091

# Bind to default interface (leave hostname empty)
listeners=PLAINTEXT://:9092
```

**Hostname meanings:**
- `0.0.0.0` - All network interfaces
- `localhost` - Loopback interface only
- Empty - Default interface
- Specific IP - That interface only

**Security protocol mapping:**

For custom protocol names, define the mapping:

```
listeners=INTERNAL://0.0.0.0:9092,EXTERNAL://0.0.0.0:9093
listener.security.protocol.map=INTERNAL:PLAINTEXT,EXTERNAL:SSL
```

**Important considerations:**

**Ports below 1024** require root privileges:
```bash
# Requires running Kafka as root (NOT recommended):
listeners=PLAINTEXT://:993
```

**Better approach:** Use ports ≥ 1024 and run Kafka as a non-root user for security.

**Deprecated parameter:** Older versions used simple `port` configuration. This still works but is deprecated in favor of the more flexible `listeners` syntax.

#### zookeeper.connect

**What it does:** Specifies the ZooKeeper ensemble used for storing broker metadata.

**Format:** Semicolon-separated list: `hostname:port/path`

**Component breakdown:**

| Component | Purpose | Example |
|-----------|---------|---------|
| hostname | ZooKeeper server address | `zoo1.example.com` |
| port | Client port number | `2181` |
| /path | Optional chroot path | `/kafka-cluster-1` |

**Examples:**

```
# Single ZooKeeper server
zookeeper.connect=localhost:2181

# Three-server ensemble (no chroot)
zookeeper.connect=zoo1.example.com:2181,zoo2.example.com:2181,zoo3.example.com:2181

# Ensemble with chroot path
zookeeper.connect=zoo1.example.com:2181,zoo2.example.com:2181,zoo3.example.com:2181/kafka-prod

# Multiple clusters sharing ZooKeeper
# Cluster 1:
zookeeper.connect=zoo1:2181,zoo2:2181,zoo3:2181/kafka-cluster-1
# Cluster 2:
zookeeper.connect=zoo1:2181,zoo2:2181,zoo3:2181/kafka-cluster-2
```

**Chroot path benefits:**

```
ZooKeeper Namespace (without chroot)
────────────────────────────────────
/brokers         ← Kafka Cluster 1
/topics          ← Conflict!
/consumers

ZooKeeper Namespace (with chroot)
─────────────────────────────────
/kafka-cluster-1/brokers  ← Cluster 1
/kafka-cluster-1/topics
/kafka-cluster-2/brokers  ← Cluster 2
/kafka-cluster-2/topics
/app-data                 ← Other apps
```

**Automatic chroot creation:** If the specified chroot path doesn't exist, Kafka creates it automatically on startup.

> **💡 Insight**
>
> Chroot paths are universally recommended, even for single-cluster deployments. They provide isolation, allow future multi-tenancy, and prevent accidental conflicts with other ZooKeeper users. Always use a chroot path like `/kafka` at minimum.

**Fault tolerance:** Specifying multiple ZooKeeper servers allows Kafka to connect to another ensemble member if one fails, maintaining availability.

#### log.dirs

**What it does:** Specifies where Kafka stores message log segments on disk.

**Relationship to log.dir:**
- `log.dir` (singular): Single directory
- `log.dirs` (plural): Multiple directories (preferred)
- If `log.dirs` is unset, falls back to `log.dir`

**Format:** Comma-separated list of paths

**Examples:**

```
# Single directory
log.dirs=/var/lib/kafka/logs

# Multiple directories (different disks for performance)
log.dirs=/disk1/kafka-logs,/disk2/kafka-logs,/disk3/kafka-logs
```

**How Kafka uses multiple directories:**

```
New Partition Assignment (Least-Used Algorithm)
───────────────────────────────────────────────
/disk1/kafka-logs  (3 partitions)  ← New partition goes here
/disk2/kafka-logs  (5 partitions)
/disk3/kafka-logs  (4 partitions)

After assignment:
/disk1/kafka-logs  (4 partitions)  ← Balanced
/disk2/kafka-logs  (5 partitions)
/disk3/kafka-logs  (4 partitions)
```

**Important limitation:** Kafka balances by **partition count**, not disk space:

```
Scenario: Uneven data distribution
──────────────────────────────────
/disk1  (2 partitions)  500GB total  ← Least partitions...
/disk2  (3 partitions)  100GB total
/disk3  (3 partitions)   50GB total

New partition goes to /disk1 despite having the most data!
```

> **💡 Insight**
>
> Kafka's "least-used" algorithm optimizes for partition balance, not disk space balance. This works well when partitions have similar data volumes. If you have vastly different partition sizes, consider external rebalancing tools like Cruise Control.

**Best practice:** Use multiple directories across different physical disks for:
- Increased throughput (parallel I/O)
- Better fault tolerance
- Improved load distribution

#### num.recovery.threads.per.data.dir

**What it does:** Controls parallelism for log segment operations during startup and shutdown.

**Default:** 1 thread per log directory

**When these threads are used:**

```
Startup (Normal)          Startup (After Crash)     Shutdown
────────────────          ─────────────────────     ────────
Open each partition's → Check each partition's → Close log segments
log segments           log segments             cleanly
                      ↓
                      Truncate inconsistent
                      data
```

**Calculation:**
```
Total threads = num.recovery.threads.per.data.dir × number of log.dirs

Example:
log.dirs=/disk1,/disk2,/disk3  (3 directories)
num.recovery.threads.per.data.dir=8
Total threads = 8 × 3 = 24 threads
```

**Impact on recovery time:**

```
Scenario: Broker with 10,000 partitions after unclean shutdown

1 thread per directory (3 total):
────────────────────────────────
Recovery time: ~4 hours

8 threads per directory (24 total):
───────────────────────────────────
Recovery time: ~30 minutes
```

**Recommended values:**
- Development: 1 (default)
- Production: 4-8 threads per directory
- Large clusters (>5000 partitions): 8-16 threads per directory

> **💡 Insight**
>
> This parameter dramatically affects recovery time but has no impact during normal operation. Set it based on your tolerance for downtime during broker restarts, especially unplanned ones.

#### auto.create.topics.enable

**What it does:** Controls whether topics are automatically created on first access.

**Default:** true

**Topics are auto-created when:**
1. A producer writes messages to a non-existent topic
2. A consumer reads from a non-existent topic
3. Any client requests metadata for a non-existent topic

**The problem with auto-creation:**

```
Developer makes typo in topic name:
───────────────────────────────────
Intended:  "user-events"
Typed:     "user-evnets"  ← Typo!

With auto.create.topics.enable=true:
────────────────────────────────────
1. Producer writes to "user-evnets"
2. Kafka auto-creates "user-evnets"
3. Data goes to wrong topic
4. Consumer reads from "user-events"
5. Sees no data
6. Hours wasted debugging!

With auto.create.topics.enable=false:
─────────────────────────────────────
1. Producer writes to "user-evnets"
2. Kafka returns error: Topic does not exist
3. Developer notices typo immediately
4. Fixes and retries
5. Problem solved in seconds!
```

**Recommended setting:**
```
# Production clusters:
auto.create.topics.enable=false

# Create topics explicitly via admin tools:
kafka-topics.sh --create --topic user-events ...
```

**Trade-offs:**
- **false**: Prevents accidents, requires explicit topic management
- **true**: Convenient for development, risky for production

> **💡 Insight**
>
> Auto-creation is convenient but dangerous. It masks configuration errors and allows garbage topics to proliferate. Mature organizations almost always disable it and use infrastructure-as-code to manage topics explicitly.

#### auto.leader.rebalance.enable

**What it does:** Automatically rebalances partition leadership across brokers to prevent imbalance.

**Default:** true

**The problem it solves:**

```
Scenario: 3-broker cluster, 9 partitions
────────────────────────────────────────

Initial state (balanced):
────────────────────────
Broker 1: Leader for partitions [0, 3, 6]
Broker 2: Leader for partitions [1, 4, 7]
Broker 3: Leader for partitions [2, 5, 8]
Load: Even distribution ✓

Broker 2 crashes and recovers:
──────────────────────────────
During crash, leadership moved:
Broker 1: Leader for partitions [0, 1, 3, 4, 6, 7]  ← Heavy!
Broker 2: Leader for partitions []                   ← Idle
Broker 3: Leader for partitions [2, 5, 8]

Without auto-rebalance: Stays unbalanced ✗
With auto-rebalance: Returns to original distribution ✓
```

**Configuration parameters:**

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `auto.leader.rebalance.enable` | true | Enable automatic rebalancing |
| `leader.imbalance.check.interval.seconds` | 300 | How often to check for imbalance |
| `leader.imbalance.per.broker.percentage` | 10 | Threshold to trigger rebalance |

**How imbalance is calculated:**

```
Imbalance % = (Current leaders - Preferred leaders) / Total partitions × 100

Example:
Broker 1: 15 actual leaders, 10 preferred leaders
Total partitions on broker: 20

Imbalance = (15 - 10) / 20 × 100 = 25%

Since 25% > 10% threshold → Triggers rebalance
```

**When to disable:**
- During planned maintenance windows
- In clusters with custom partition assignment logic
- When using external rebalancing tools

#### delete.topic.enable

**What it does:** Controls whether topics can be deleted.

**Default:** true (varies by version)

**Setting to false:**
```
# Prevent accidental topic deletion
delete.topic.enable=false
```

**When deletion is attempted:**
```
With delete.topic.enable=true:
──────────────────────────────
kafka-topics.sh --delete --topic important-data
→ Topic deleted ✓

With delete.topic.enable=false:
───────────────────────────────
kafka-topics.sh --delete --topic important-data
→ Topic marked for deletion, but not actually deleted
→ Administrator must manually re-enable and delete
```

**Use cases for disabling:**
- Regulatory environments requiring strict data retention
- Preventing accidental deletion of critical topics
- Clusters managed by multiple teams with varying privileges

> **💡 Insight**
>
> In highly regulated industries (finance, healthcare), disabling topic deletion adds a safety layer. However, it also complicates legitimate cleanup operations. Consider whether your security model requires this restriction.

### 5.2. Topic Defaults

Kafka allows per-topic configuration overrides, but broker-level defaults provide baseline values for new topics.

**In plain English:** Topic defaults are like default settings on your phone - they apply to everything unless you specifically override them for individual apps.

**Important deprecation:**

Older Kafka versions allowed broker-level per-topic overrides:
```
# OLD WAY (no longer supported):
log.retention.hours.per.topic=my-topic:24
log.retention.bytes.per.topic=my-topic:1073741824
```

**New approach:** Set defaults in broker configuration, override per-topic using admin tools (covered in Chapter 12).

#### num.partitions

**What it does:** Sets the default partition count for new topics (when using auto-creation or when not specified explicitly).

**Default:** 1

**Critical limitation:** Partition count can only be **increased**, never decreased.

```
Partition Lifecycle
───────────────────
Created with 3 partitions  → Can increase to 6 ✓
                          → Cannot decrease to 2 ✗
```

**Choosing partition count:**

**Factor 1: Throughput requirements**
```
Target throughput: 1 GB/s writes
Single partition max: 100 MB/s

Required partitions: 1 GB/s ÷ 100 MB/s = 10 partitions
```

**Factor 2: Consumer parallelism**
```
Scenario: 4 partitions, 6 consumers

Consumer distribution:
────────────────────
Consumer 1 → Partition 0
Consumer 2 → Partition 1
Consumer 3 → Partition 2
Consumer 4 → Partition 3
Consumer 5 → Idle (no partition available)
Consumer 6 → Idle (no partition available)

Max parallelism = partition count (4 consumers working, 2 idle)
```

**Factor 3: Message key distribution**

If using message keys for ordering:
```
With 3 partitions:
─────────────────
key=user_123 → hash(user_123) % 3 = Partition 1
key=user_456 → hash(user_456) % 3 = Partition 0

Adding partitions later (now 6 partitions):
──────────────────────────────────────────
key=user_123 → hash(user_123) % 6 = Partition 3  ← Different!

Breaks key-based ordering and consumer logic!
```

**Common strategies:**

```
Strategy 1: Match broker count
─────────────────────────────
10 brokers → 10 partitions per topic
Even distribution, simple mental model

Strategy 2: Multiple of broker count
────────────────────────────────────
10 brokers → 20-30 partitions per topic
Better balance during rebalancing

Strategy 3: Throughput-based
────────────────────────────
Calculate based on producer/consumer rates
Most accurate but requires measurement
```

**Practical guidelines:**

```
Small cluster (3 brokers):
  - Low-volume topics: 3 partitions
  - Medium-volume: 6 partitions
  - High-volume: 12+ partitions

Large cluster (20+ brokers):
  - Start with 20 partitions
  - Increase based on monitoring
  - Limit: ~6 GB/day per partition (retention-based)
```

> **💡 Insight**
>
> Partitioning is a one-way door - you can add partitions but never remove them. Start conservatively (fewer partitions) and increase based on actual throughput measurements. Over-partitioning wastes resources and increases metadata overhead.

**Advanced considerations:**

**1. Broker resource limits:**
```
Recommended limits:
  - Max 14,000 partition replicas per broker
  - Max 1,000,000 partition replicas per cluster

Example calculation:
  20 brokers × 14,000 replicas = 280,000 total capacity
  With replication factor 3:
    280,000 ÷ 3 = ~93,000 partitions max
```

**2. IOPS limitations (cloud environments):**
- More partitions = More files = More IOPS
- Cloud VMs often have IOPS quotas
- Monitor disk metrics when scaling partitions

**3. Mirroring considerations:**
- Large partitions increase mirroring lag
- Consider throughput of mirroring links

#### default.replication.factor

**What it does:** Sets the default replication factor for auto-created topics.

**Default:** 1 (no replication)

**What replication means:**

```
Replication Factor = 1 (No replication)
──────────────────────────────────────
Partition 0 exists on: Broker 1 only
If Broker 1 fails → Data lost ✗

Replication Factor = 2
──────────────────────
Partition 0 Leader:    Broker 1
Partition 0 Follower:  Broker 2
If Broker 1 fails → Broker 2 becomes leader ✓

Replication Factor = 3
──────────────────────
Partition 0 Leader:    Broker 1
Partition 0 Follower:  Broker 2
Partition 0 Follower:  Broker 3
If Broker 1 fails → Broker 2 or 3 becomes leader ✓
Can survive 2 failures!
```

**Recommended configuration pattern (RF++):**

```
RF++ Strategy: replication.factor = min.insync.replicas + 2

Example:
  min.insync.replicas=2
  default.replication.factor=4  (2 + 2)

Fault tolerance:
  - 1 planned outage (rolling restart)
  - 1 unplanned outage (hardware failure)
  - Still have 2 in-sync replicas for writes
```

**Common configurations:**

| Environment | Replication Factor | min.insync.replicas | Fault Tolerance |
|-------------|-------------------|---------------------|-----------------|
| Development | 1 | 1 | None |
| Testing | 2 | 1 | 1 failure |
| Production (standard) | 3 | 2 | 2 failures |
| Production (critical) | 4 | 2 | 3 failures |

**Storage multiplication:**

```
Scenario: 10 TB raw data, replication factor 3
──────────────────────────────────────────────
Actual storage required: 10 TB × 3 = 30 TB

Each replica consumes:
  - Disk space
  - Network bandwidth (during replication)
  - IOPS (for replication writes)
```

> **💡 Insight**
>
> Replication is your insurance policy against data loss. Replication factor 3 with min.insync.replicas=2 is the industry standard for production systems, balancing durability with performance. Higher values provide more safety but at the cost of storage and throughput.

**Relationship to min.insync.replicas:**

This parameter is covered under [min.insync.replicas](#min-insync-replicas) below but works in tandem with replication factor to ensure data durability.

#### log.retention.ms

**What it does:** Controls how long Kafka retains messages before deleting them.

**Default:** 168 hours (7 days) via `log.retention.hours`

**Available parameters (priority order):**
1. `log.retention.ms` (milliseconds) - Highest priority
2. `log.retention.minutes` (minutes)
3. `log.retention.hours` (hours) - Default

**Best practice:** Always use `log.retention.ms` to avoid ambiguity.

```
Configuration example:
log.retention.ms=604800000   # 7 days in milliseconds

Calculation:
7 days × 24 hours × 60 minutes × 60 seconds × 1000 milliseconds
= 604,800,000 ms
```

**How retention works:**

```
Timeline (7-day retention):
───────────────────────────

Day 0: Messages written to segment file "00000000000000000000.log"
Day 1: ...
Day 7: Segment closed
Day 8: Segment eligible for deletion (based on last modified time)
       ↓
       Segment deleted
```

**Important timing detail:**

Retention is based on **segment close time**, not message timestamp:

```
Scenario: Low-volume topic
──────────────────────────
Day 0-9:  Messages accumulate (segment not full, stays open)
Day 10:   Segment reaches size limit (1 GB), closes
Day 17:   Segment deleted (7 days after close)

Actual retention: 17 days of data!
(10 days accumulating + 7 days retention)
```

**Common retention periods:**

| Use Case | Retention Period | Reasoning |
|----------|------------------|-----------|
| Real-time metrics | 1-3 days | Recent data only |
| User activity logs | 7-30 days | Audit compliance |
| Financial transactions | 90+ days | Regulatory requirements |
| Change data capture | Infinite (`-1`) | System of record |

> **💡 Insight**
>
> Retention controls storage costs directly. A topic receiving 1 TB/day with 30-day retention needs 30 TB storage (plus replication). Balance business needs against infrastructure costs. Use log compaction for infinite retention of latest state.

#### log.retention.bytes

**What it does:** Limits retention by total partition size rather than time.

**Default:** -1 (infinite, only time-based retention applies)

**Applied per partition:**

```
Configuration:
log.retention.bytes=1073741824  # 1 GB

Topic with 8 partitions:
────────────────────────
Total retention: 8 partitions × 1 GB = 8 GB

If partitions are expanded to 12:
Total retention: 12 partitions × 1 GB = 12 GB
```

**Combining time and size retention:**

```
Configuration:
log.retention.ms=86400000      # 1 day
log.retention.bytes=1073741824 # 1 GB per partition

Deletion occurs when EITHER condition is met:

Scenario A: High-volume topic
  Day 1: Partition reaches 1 GB at 2 PM
  → Deleted at 2 PM (size limit hit first)

Scenario B: Low-volume topic
  Day 1: Partition has 500 MB at midnight
  → Deleted next day at midnight (time limit hit first)
```

**Visual representation:**

```
Time-based only:
────────────────
|-------- 7 days --------|
                         ↓ Delete

Size-based only:
────────────────
[Growing size...] 1 GB
                      ↓ Delete

Combined (both):
────────────────
Whichever happens first triggers deletion
```

**Best practice:** Use **either** time-based **or** size-based retention, not both, to avoid unpredictable behavior.

> **💡 Insight**
>
> Size-based retention makes capacity planning easier ("we can store X GB per topic") but creates operational complexity during traffic spikes. Time-based retention aligns better with business requirements ("keep 30 days of data"). Choose based on your primary constraint.

#### log.segment.bytes

**What it does:** Controls when Kafka closes the current log segment and opens a new one.

**Default:** 1073741824 (1 GB)

**Why it matters:**

Retention operates on **closed segments only**:

```
Active segment (being written to):
──────────────────────────────────
Never deleted, regardless of message age

Closed segments:
────────────────
Eligible for deletion based on retention policies
```

**Impact on actual retention:**

```
Example: Low-volume topic
─────────────────────────

Configuration:
  log.segment.bytes=1073741824  # 1 GB
  log.retention.ms=604800000     # 7 days

Traffic: 100 MB/day

Segment timeline:
  Day 0-9:    Messages accumulate (1 GB not yet reached)
  Day 10:     Segment hits 1 GB, closes
  Day 10-17:  Closed segment retained (7-day countdown)
  Day 17:     Segment deleted

Actual data retention: 17 days (not 7 days!)
```

**Adjusting for low-volume topics:**

```
Problem: Topic receives 100 MB/day
  Default 1 GB segment = 10 days to fill
  With 7-day retention = up to 17 days actual retention

Solution: Reduce segment size
  log.segment.bytes=104857600  # 100 MB
  Now segment closes daily
  Actual retention ≈ 8 days (close to 7-day target)
```

**Trade-offs:**

| Segment Size | Pros | Cons |
|--------------|------|------|
| Large (1 GB+) | Fewer files, less overhead | Delayed retention, coarse timestamp lookup |
| Small (100 MB) | Precise retention, fine-grained timestamp | More files, more overhead |

**Impact on offset-by-timestamp queries:**

```
Request: Find offset at timestamp 2023-10-15 10:30:00

Process:
1. Kafka finds segment file active at that time
2. Uses file creation time and last modified time
3. Returns offset at start of that segment

With 1 GB segments:
  Returns offset accurate to ±hours

With 100 MB segments:
  Returns offset accurate to ±minutes
```

> **💡 Insight**
>
> Segment size affects retention precision, file count, and timestamp query accuracy. For most workloads, 1 GB is appropriate. Adjust smaller for low-volume topics or when precise timestamp queries matter. Avoid tiny segments (<50 MB) due to file system overhead.

#### log.roll.ms

**What it does:** Forces segment closure after a time period, regardless of size.

**Default:** Not set (only size triggers segment closure)

**Use case:** Ensures timely retention even for low-volume topics.

```
Without log.roll.ms:
────────────────────
Low-volume topic never reaches segment size limit
→ Segment stays open indefinitely
→ Retention never applies

With log.roll.ms=86400000 (1 day):
──────────────────────────────────
Segment closes after 24 hours regardless of size
→ Retention applies predictably
```

**Combined with log.segment.bytes:**

```
Configuration:
  log.segment.bytes=1073741824  # 1 GB
  log.roll.ms=86400000          # 1 day

Segment closes when EITHER condition is met:

High-volume scenario:
  Hour 12: Reaches 1 GB
  → Segment closes (size limit hit first)

Low-volume scenario:
  Hour 24: Only 100 MB written
  → Segment closes (time limit hit first)
```

**Performance consideration:**

```
Scenario: 100 low-volume partitions
────────────────────────────────────
All partitions created at broker startup
All have log.roll.ms=86400000

Result:
  All 100 segments close simultaneously every 24 hours
  → Disk I/O spike
  → Potential performance degradation
```

**Stagger segment closures for large clusters** by using slightly different roll times per topic or accepting natural variation from partition creation times.

> **💡 Insight**
>
> Time-based segment rolling ensures predictable retention behavior for variable-traffic topics. The trade-off is potential disk I/O spikes when many segments close simultaneously. Monitor and adjust if you observe periodic performance degradation.

#### min.insync.replicas

**What it does:** Defines minimum replicas that must acknowledge writes for producers using `acks=all`.

**Default:** 1

**Durability guarantee:**

```
Configuration:
  min.insync.replicas=2
  Producer uses: acks=all

Write process:
──────────────
1. Producer sends message
2. Leader writes to log
3. Leader waits for 1 follower to replicate
4. Leader acknowledges to producer
5. Producer considers write successful

If only leader available:
  → Write rejected (not enough in-sync replicas)
  → Producer receives error
```

**Preventing data loss:**

```
Scenario: min.insync.replicas=1, acks=all
──────────────────────────────────────────

Step 1: Producer writes message
Step 2: Leader acknowledges (only 1 replica: leader itself)
Step 3: Producer considers write successful
Step 4: Leader crashes BEFORE followers replicate
Step 5: Follower becomes leader (missing message)

Result: Data lost! ✗

Scenario: min.insync.replicas=2, acks=all
─────────────────────────────────────────

Step 1: Producer writes message
Step 2: Leader waits for follower replication
Step 3: Leader acknowledges (2 replicas: leader + follower)
Step 4: Leader crashes
Step 5: Follower becomes leader (has message)

Result: Data preserved! ✓
```

**Availability trade-off:**

```
Configuration:
  replication.factor=3
  min.insync.replicas=2

Availability:
  3 replicas available: ✓ Writes succeed
  2 replicas available: ✓ Writes succeed
  1 replica available:  ✗ Writes fail (below minimum)
```

**Common configurations:**

| Use Case | Replication Factor | min.insync.replicas | Behavior |
|----------|-------------------|---------------------|----------|
| Maximum availability | 3 | 1 | Accepts writes with only leader |
| Balanced | 3 | 2 | Requires leader + 1 follower (recommended) |
| Maximum durability | 5 | 3 | Requires leader + 2 followers |

**Performance impact:**

```
min.insync.replicas=1:
  Leader acks immediately
  Higher throughput, lower latency

min.insync.replicas=2:
  Leader waits for follower
  Moderate throughput, moderate latency

min.insync.replicas=3:
  Leader waits for 2 followers
  Lower throughput, higher latency
```

> **💡 Insight**
>
> `min.insync.replicas=2` with `acks=all` is the industry standard for durability without excessive performance cost. It protects against single-broker failure while maintaining reasonable throughput. Higher values provide more safety but reduce availability during outages.

**Must coordinate with producer settings:**

This setting only takes effect when producers use `acks=all` (or `acks=-1`). Producers using `acks=1` or `acks=0` bypass this safety mechanism.

#### message.max.bytes

**What it does:** Sets the maximum size for a single message.

**Default:** 1000000 (1 MB)

**Important:** Size limit applies to **compressed** messages.

```
Uncompressed message size: 5 MB
Compression ratio: 5:1
Compressed message size: 1 MB
→ Accepted ✓

Uncompressed message size: 10 MB
Compression ratio: 2:1
Compressed message size: 5 MB
→ Rejected (exceeds 1 MB limit) ✗
```

**Error handling:**

```
Producer sends 2 MB message:
────────────────────────────
Broker: Returns error "Message too large"
Producer: Receives error, message not written
Application: Must handle error (retry with smaller message, split, etc.)
```

**Performance implications:**

```
Impact of larger message size:
──────────────────────────────

Network threads:
  Process each request longer
  → Reduced request throughput

Disk I/O:
  Larger writes take more time
  → Reduced I/O throughput

Memory:
  Larger buffers needed
  → Higher memory pressure
```

**Must coordinate with consumers:**

```
Broker configuration:
  message.max.bytes=2097152  # 2 MB

Consumer configuration (must match or exceed):
  fetch.message.max.bytes=2097152  # 2 MB or larger

Mismatch scenario:
  Broker: message.max.bytes=2097152     (2 MB)
  Consumer: fetch.message.max.bytes=1048576  (1 MB)

  Result:
  - 2 MB messages written successfully
  - Consumer cannot fetch them (too large)
  - Consumer stuck! ✗
```

**Cluster configuration:**

```
In multi-broker clusters, also set:
  replica.fetch.max.bytes=2097152

Otherwise:
  - Leader accepts 2 MB messages
  - Followers cannot replicate them
  - Replication stuck! ✗
```

**Alternatives to large messages:**

```
Instead of increasing message.max.bytes:
────────────────────────────────────────

1. Store data externally (S3, object store)
   Send reference in Kafka message:
   { "data_url": "s3://bucket/large-file.bin" }

2. Use tiered storage (Kafka 2.8+)
   Offload large/old segments to object storage

3. Split large payloads
   Send across multiple messages with sequence IDs
```

> **💡 Insight**
>
> Larger message sizes create cascading performance impacts across the entire pipeline. Before increasing limits, consider whether Kafka is the right tool for large payloads. For most use cases, keeping messages under 1 MB and using references to external storage provides better performance and flexibility.

---

## 6. Selecting Hardware

**In plain English:** Hardware selection is like choosing between a sports car and a truck - both transport you, but each excels at different tasks. Kafka's hardware needs depend on your specific workload.

Kafka will run on almost any hardware, but **performance** depends on selecting the right balance of:
- **Disk** throughput and capacity
- **Memory** for page caching
- **Network** bandwidth
- **CPU** for compression/decompression

Let's explore each component.

### 6.1. Disk Throughput

**In plain English:** Disk throughput determines how fast producers can write data - it's your input bottleneck.

**Why it matters:**

```
Producer workflow:
──────────────────
Message → Network → Kafka Broker → Disk
                                    ↓
                              Write must complete
                              before acknowledging

Faster disk writes = Lower produce latency
```

**Technology choices:**

| Technology | Throughput | Latency | Cost | Best For |
|------------|-----------|---------|------|----------|
| HDD (7200 RPM) | ~100 MB/s | 10-20ms | $ | High capacity, lower throughput |
| HDD (10K RPM) | ~150 MB/s | 5-10ms | $$ | Balanced workloads |
| SSD (SATA) | ~500 MB/s | <1ms | $$$ | High throughput |
| SSD (NVMe) | ~3000 MB/s | <0.1ms | $$$$ | Extreme performance |

**Improving HDD performance:**

**1. Use multiple drives:**
```
Single drive:  100 MB/s throughput

Three drives (separate log.dirs):
  /disk1/kafka-logs
  /disk2/kafka-logs
  /disk3/kafka-logs

Combined: ~300 MB/s throughput
```

**2. RAID configurations:**
```
RAID 0 (Striping):
  Performance: Excellent (N × single drive speed)
  Reliability: Poor (any drive failure loses all data)
  Use case: Only if replication.factor ≥ 3

RAID 10 (Stripe + Mirror):
  Performance: Good (N/2 × single drive speed)
  Reliability: Good (tolerates drive failures)
  Use case: Critical data, limited cluster size
```

**3. Drive quality matters:**
```
Consumer-grade SATA: High failure rate, inconsistent performance
Enterprise SAS:      Lower failure rate, consistent performance
Data center NVMe:    Lowest failure rate, highest performance
```

**Choosing based on workload:**

```
Workload: Many client connections, low latency needed
───────────────────────────────────────────────────────
Recommendation: SSD
Reason: Fast random access, low seek times

Workload: High storage capacity, batch processing
─────────────────────────────────────────────────
Recommendation: HDD arrays
Reason: Cost-effective capacity, sequential I/O acceptable
```

> **💡 Insight**
>
> Kafka's sequential write pattern makes it HDD-friendly - you don't need expensive SSDs for many workloads. However, SSDs shine when you have many concurrent client connections, each creating random I/O patterns. Measure your actual I/O patterns before over-investing in storage.

### 6.2. Disk Capacity

**In plain English:** Disk capacity is your data warehouse size - it determines how much history you can keep.

**Capacity calculation:**

```
Formula:
────────
Required capacity = Daily traffic × Retention days × Replication factor × Overhead

Example:
────────
Daily traffic:      1 TB
Retention:          7 days
Replication factor: 3
Overhead:           1.1 (10%)

Calculation:
1 TB/day × 7 days × 3 replicas × 1.1 = 23.1 TB required
```

**Overhead sources:**

```
Overhead components:
────────────────────
1. ZooKeeper metadata:        ~100 MB
2. Index files:                ~0.5% of data size
3. Transaction logs:           ~1% of data size
4. Snapshot files:             ~1% of data size
5. Administrative headroom:    ~5-10%
                               ─────────
Total overhead:                ~10-15%
```

**Capacity planning for growth:**

```
Current state:
  Daily traffic: 1 TB
  Expected growth: 20% per year
  Planning horizon: 3 years

Year 1: 1.0 TB/day × 7 days × 3 replicas = 21 TB
Year 2: 1.2 TB/day × 7 days × 3 replicas = 25.2 TB
Year 3: 1.44 TB/day × 7 days × 3 replicas = 30.2 TB

Provision: 35 TB (includes growth + buffer)
```

**Cluster expansion strategies:**

**Vertical scaling:**
```
Current: 5 brokers × 4 TB = 20 TB total
Upgrade: 5 brokers × 8 TB = 40 TB total

Pros: Simple, no rebalancing
Cons: Limited by single-broker capacity, expensive
```

**Horizontal scaling:**
```
Current: 5 brokers × 4 TB = 20 TB total
Expand:  10 brokers × 4 TB = 40 TB total

Pros: Better fault tolerance, lower per-broker load
Cons: Requires partition rebalancing, more complex
```

> **💡 Insight**
>
> Capacity planning should account for peak traffic, not average. A Black Friday surge or viral event can 10× your normal traffic. Plan for bursts, or use retention policies that automatically expire old data to maintain fixed capacity.

### 6.3. Memory

**In plain English:** Memory is your cache - it keeps frequently accessed data readily available, like keeping popular books at the front desk instead of in the stacks.

**How Kafka uses memory:**

```
Total System Memory Split:
──────────────────────────

JVM Heap (Kafka broker):
  ├─ 5-6 GB for broker operations
  └─ Message buffers, connection state

OS Page Cache (remaining memory):
  ├─ Recently written messages
  ├─ Frequently read log segments
  └─ File system metadata

Example: 64 GB RAM server
─────────────────────────
JVM heap:     5 GB
Page cache:   59 GB  ← This is where the magic happens!
```

**Why page cache matters:**

```
Consumer reads recent data (common case):
─────────────────────────────────────────

Without page cache:
  Consumer request → Broker → Disk read → Network send
  Latency: ~10ms (disk seek + read)

With page cache:
  Consumer request → Broker → Memory read → Network send
  Latency: ~0.1ms (memory access)

Performance improvement: 100× faster!
```

**Memory sizing guidelines:**

```
Conservative (minimum):
  32 GB RAM
  ├─ 5 GB JVM heap
  └─ 27 GB page cache

Standard production:
  64 GB RAM
  ├─ 5 GB JVM heap
  └─ 59 GB page cache

High-performance:
  128-256 GB RAM
  ├─ 5-8 GB JVM heap
  └─ 120-248 GB page cache
```

**Why Kafka doesn't need large JVM heap:**

```
Broker with impressive stats:
  - 150,000 messages/second
  - 200 Mbps data rate

Runs comfortably with 5 GB heap!

Why?
  - Messages stored on disk, not in heap
  - JVM only holds connection state and buffers
  - OS page cache does the heavy lifting
```

**Colocation warning:**

```
Scenario: Sharing server with other applications
────────────────────────────────────────────────

64 GB server:
  Kafka JVM:           5 GB
  Other app JVM:      10 GB
  Other app cache:    20 GB
  Available for OS:   29 GB

Kafka's page cache: Only 29 GB (instead of 59 GB)
Consumer performance: Degraded ✗

Recommendation: Dedicate servers to Kafka
```

> **💡 Insight**
>
> Kafka's architecture inverts typical application design - rather than caching data in the JVM heap, it relies on the OS page cache. This is why Kafka needs lots of RAM but a small heap. Co-locating Kafka with memory-hungry applications destroys this advantage by stealing page cache.

### 6.4. Networking

**In plain English:** Network bandwidth is your delivery capacity - it determines how many consumers can read data simultaneously without bottlenecking.

**Understanding network multiplication:**

```
Producer writes 1 MB/s:
───────────────────────

Inbound traffic:  1 MB/s

But outbound traffic with consumers:
  Consumer A:        1 MB/s
  Consumer B:        1 MB/s
  Consumer C:        1 MB/s
  Replication:       1 MB/s (to other brokers)
  Mirroring:         1 MB/s (to DR cluster)
                     ─────────
Total outbound:      5 MB/s

Network ratio: 5:1 outbound vs. inbound
```

**Saturation risks:**

```
1 Gbps network interface = 125 MB/s theoretical max
                          = ~100 MB/s practical max

Scenario: 50 MB/s inbound, 3 consumers, replication
──────────────────────────────────────────────────
Inbound:         50 MB/s
Outbound:
  3 consumers:   150 MB/s
  Replication:    50 MB/s
                 ─────────
Total outbound:  200 MB/s

200 MB/s > 100 MB/s capacity → Network saturated! ✗
```

**Impact of saturation:**

```
When network saturates:
───────────────────────
1. Replication lag increases
   → Replicas fall behind
   → Reduced fault tolerance

2. Consumer lag increases
   → Real-time processing delayed
   → SLA violations

3. Producer timeouts
   → Failed writes
   → Data loss risk
```

**Network interface recommendations:**

| Network | Max Throughput | Use Case |
|---------|---------------|----------|
| 1 Gbps | ~100 MB/s | Development only |
| 10 Gbps | ~1000 MB/s | Production minimum (recommended) |
| 25 Gbps | ~2500 MB/s | High-throughput clusters |
| 40 Gbps | ~4000 MB/s | Extreme performance needs |

**Configuration for high-throughput:**

```
Recommended: 10 Gbps NICs minimum

Example capacity:
  10 Gbps = 1,000 MB/s

Comfortable usage:
  Inbound:   200 MB/s
  Outbound:  600 MB/s (3× multiplication)
  Total:     800 MB/s (80% utilization)

Headroom:  200 MB/s (20%) for bursts
```

> **💡 Insight**
>
> Network becomes your primary bottleneck as your cluster grows. A single saturated NIC can cascade into cluster-wide instability - replication fails, consumers lag, producers timeout. Always provision 10 Gbps NICs for production. The small incremental cost prevents expensive outages.

### 6.5. CPU

**In plain English:** CPU is your processing power - usually not a bottleneck until your cluster grows very large, but it matters for compression-heavy workloads.

**Where Kafka uses CPU:**

```
Producer sends compressed batch:
────────────────────────────────
1. Broker receives compressed data
2. Broker decompresses batch
3. Broker validates individual message checksums
4. Broker assigns offsets
5. Broker recompresses batch
6. Broker writes to disk

Steps 2-5 are CPU-intensive!
```

**CPU usage patterns:**

```
Workload: No compression
────────────────────────
CPU usage: 10-20% (mostly network/disk I/O)

Workload: Gzip compression (max compression)
────────────────────────────────────────────
CPU usage: 40-60% (decompression/validation/recompression)

Workload: LZ4 compression (fast compression)
────────────────────────────────────────────
CPU usage: 20-30% (lighter compression overhead)
```

**When CPU becomes critical:**

```
Small cluster (3-10 brokers):
  CPU rarely a bottleneck
  Focus on disk/network first

Medium cluster (10-50 brokers):
  CPU matters for heavy compression
  Monitor during peak load

Large cluster (100+ brokers):
  CPU affects controller performance
  Higher core counts reduce cluster size

Very large cluster (1000+ partitions per broker):
  CPU directly impacts metadata operations
  Premium CPUs reduce operational complexity
```

**Scaling consideration:**

```
Scenario: Need 50,000 partitions total

Option A: Lower-CPU brokers
  20 brokers × 2,500 partitions each
  More brokers = more operational complexity

Option B: Higher-CPU brokers
  15 brokers × 3,333 partitions each
  Fewer brokers = simpler operations

Higher CPU allows consolidation
```

**CPU selection guidance:**

```
Development/Testing:
  4-8 cores sufficient

Production (standard):
  8-16 cores recommended

Production (high compression):
  16-32 cores for CPU headroom

Production (very large scale):
  32+ cores to reduce broker count
```

> **💡 Insight**
>
> CPU is your least important hardware consideration for most Kafka deployments - until it suddenly becomes critical at scale. Prioritize disk and network first. Revisit CPU when you hit hundreds of brokers or notice compression bottlenecks. Modern multi-core CPUs provide ample headroom for typical workloads.

---

## 7. Kafka in the Cloud

Running Kafka in cloud environments (Azure, AWS, GCP) introduces different considerations than bare-metal deployments.

**In plain English:** Cloud Kafka is like renting an apartment - you have more flexibility and less upfront cost, but you need to understand the landlord's rules (quotas, performance tiers, pricing models).

**Managed vs. self-managed:**

```
Managed Kafka (Confluent Cloud, Azure Event Hubs, AWS MSK):
──────────────────────────────────────────────────────────
Pros: No operations burden, automatic scaling, SLA guarantees
Cons: Higher cost, less control, vendor lock-in

Self-Managed Kafka on Cloud VMs:
─────────────────────────────────
Pros: Full control, lower cost at scale, portable
Cons: Operational burden, manual scaling, self-support
```

This section covers **self-managed Kafka** on cloud infrastructure.

### 7.1. Microsoft Azure

**Key Azure characteristics:**
- Compute (VMs) and storage (disks) are managed separately
- Storage options range from cheap HDD to premium SSD
- Availability sets provide fault domain isolation

**VM selection guidance:**

```
Small clusters / Development:
──────────────────────────────
Standard D16s v3
  - 16 vCPUs, 64 GB RAM
  - Good balance for most workloads
  - Cost-effective starting point

Large clusters / Production:
────────────────────────────
Standard D64s v4
  - 64 vCPUs, 256 GB RAM
  - Handles high throughput
  - Scales for large partition counts
```

**Storage options:**

| Storage Type | Performance | Availability SLA | Cost | Use Case |
|--------------|-------------|------------------|------|----------|
| HDD Managed Disks | Low | No formal SLA | $ | Development only |
| Standard SSD | Moderate | 99.5% | $$ | Testing environments |
| Premium SSD | High | 99.9% | $$$ | Production (recommended) |
| Ultra SSD | Very High | 99.99% | $$$$ | Extreme performance |
| Azure Blob Storage | Variable | 99.9% | $ | Tiered storage, archives |

**Recommended production configuration:**

```
VM Configuration:
─────────────────
Instance type:  Standard D64s v4
  vCPUs:        64
  RAM:          256 GB

Storage:
────────
System disk:    Premium SSD (128 GB)
Data disks:     3× Premium SSD (2 TB each)
  Configured as separate log.dirs:
    /disk1/kafka-logs
    /disk2/kafka-logs
    /disk3/kafka-logs

Network:
────────
Accelerated networking: Enabled
Expected throughput:    ~8 Gbps

Availability:
─────────────
Availability set:       Enabled
Fault domain spread:    Max (typically 3)
```

**Availability set configuration:**

```
Availability Set: "kafka-prod-avail-set"
────────────────────────────────────────
Fault Domain 1:  kafka-broker-1, kafka-broker-4
Fault Domain 2:  kafka-broker-2, kafka-broker-5
Fault Domain 3:  kafka-broker-3, kafka-broker-6

Benefit: Replicas spread across fault domains
→ Hardware failure in one domain doesn't lose all replicas
```

**Critical: Use managed disks, not ephemeral**

```
Ephemeral (temp) disks:
───────────────────────
Data lost when VM moves/restarts
NEVER use for Kafka data! ✗

Azure Managed Disks:
────────────────────
Data persists across VM lifecycle
Required for Kafka ✓
```

> **💡 Insight**
>
> Azure's separate compute/storage model provides flexibility but requires careful planning. Premium SSD Managed Disks are essential for production - the SLA and performance justify the cost. Ultra SSD is overkill for most Kafka workloads unless you're in the top 1% of throughput requirements.

### 7.2. Amazon Web Services

**Key AWS characteristics:**
- Tightly coupled compute and storage (instance types)
- Storage types: EBS (network-attached) vs. Instance Store (local SSD)
- Placement groups provide low-latency networking

**Instance type selection:**

```
Development / Testing:
──────────────────────
m4 family (EBS-optimized)
  m4.xlarge:  4 vCPUs, 16 GB RAM, EBS storage
  m4.2xlarge: 8 vCPUs, 32 GB RAM, EBS storage

Pros: Flexible storage size, data persists
Cons: Network-attached storage (higher latency)

Production (Balanced):
──────────────────────
r3 family (Instance Store)
  r3.2xlarge: 8 vCPUs, 61 GB RAM, 160 GB SSD
  r3.4xlarge: 16 vCPUs, 122 GB RAM, 320 GB SSD

Pros: Low-latency local SSD, good throughput
Cons: Limited storage capacity, data lost on termination

Production (High Throughput):
─────────────────────────────
i2 family (Dense storage, NVMe SSD)
  i2.2xlarge: 8 vCPUs, 61 GB RAM, 1.6 TB SSD

Production (High Capacity):
───────────────────────────
d2 family (Dense storage, HDD)
  d2.2xlarge: 8 vCPUs, 61 GB RAM, 12 TB HDD
```

**Storage trade-offs:**

```
EBS (Elastic Block Store):
──────────────────────────
Pros:
  - Flexible capacity (resize on the fly)
  - Data persists (broker restart safe)
  - Snapshots for backups

Cons:
  - Network-attached (higher latency)
  - Lower throughput than local SSD
  - Additional cost

Instance Store (Local SSD):
───────────────────────────
Pros:
  - Very low latency (directly attached)
  - High throughput (NVMe)
  - Included in instance cost

Cons:
  - Fixed capacity (can't resize)
  - Data lost on termination
  - No snapshots
```

**Best-of-both-worlds approach:**

```
i3 or i3en families (newer generation):
───────────────────────────────────────
Combines:
  - Local NVMe SSD (high performance)
  - Large capacity (up to 60 TB on i3en.24xlarge)
  - Better CPU and network than i2/d2

Recommended for large production clusters
```

**Example production architecture:**

```
Configuration: 10-broker cluster on i3.2xlarge
───────────────────────────────────────────────

Per-broker specs:
  vCPUs:          8
  RAM:            61 GB
  Instance Store: 1.9 TB NVMe SSD
  Network:        Up to 10 Gbps

Cluster capacity:
  Total storage:  19 TB raw
  With RF=3:      ~6.3 TB effective capacity

Risk mitigation:
  Replication factor ≥ 3 (protects against instance loss)
  Regular offset backups
  Disaster recovery to another region
```

> **💡 Insight**
>
> AWS instance types force trade-offs between storage capacity and performance. For production, i3 instances provide the best balance - fast local NVMe SSD with reasonable capacity. Always use replication factor ≥ 3 with instance store to protect against data loss. If you need EBS for data persistence, ensure you provision sufficient IOPS to avoid throttling.

---

## 8. Configuring Kafka Clusters

A single broker works for development, but production deployments require **multi-broker clusters** for scalability and fault tolerance.

**In plain English:** A cluster is like moving from a one-person shop to a team - you can handle more work, and if one person is sick, the others cover for them.

**Benefits of clusters:**

```
Single Broker:
──────────────
Throughput:      Limited to one server's capacity
Fault Tolerance: None (broker failure = total outage)
Maintenance:     Downtime required

Multi-Broker Cluster:
─────────────────────
Throughput:      Scales with broker count
Fault Tolerance: Survives broker failures
Maintenance:     Rolling restarts (no downtime)
```

**Visual representation:**

```
3-Broker Kafka Cluster
──────────────────────

         ZooKeeper Ensemble
              ↕ metadata
    ┌─────────┴─────────┐
    │                   │
┌───▼────┐  ┌────────┐  ┌────────┐
│Broker 1│  │Broker 2│  │Broker 3│
│ID: 1   │  │ID: 2   │  │ID: 3   │
└────────┘  └────────┘  └────────┘
    │            │           │
    └────────────┴───────────┘
         Replication
```

### 8.1. How Many Brokers?

Cluster size depends on multiple factors:

**Factor 1: Disk capacity**

```
Calculation:
────────────
Required data retention:   10 TB
Replication factor:        3
Effective capacity needed: 10 TB × 3 = 30 TB

Per-broker disk:           6 TB
Minimum brokers:           30 TB ÷ 6 TB = 5 brokers
```

**Factor 2: Replica capacity per broker**

```
Current limits (well-configured environment):
─────────────────────────────────────────────
Per broker:   14,000 partition replicas (recommended max)
Per cluster:  1,000,000 partition replicas (recommended max)

Example calculation:
────────────────────
Total partitions needed:   500,000
Replication factor:        2
Total replicas:            1,000,000

Minimum brokers: 1,000,000 ÷ 14,000 = ~72 brokers
```

**Factor 3: CPU capacity**

```
Scenario: Heavy compression workload
────────────────────────────────────
Current: 10 brokers at 80% CPU utilization
Problem: No headroom for traffic spikes

Solution: Add brokers to reduce per-broker CPU
Target:  10 brokers → 15 brokers
Result:  CPU drops to ~53% per broker
```

**Factor 4: Network capacity**

```
Peak traffic analysis:
──────────────────────
Inbound:              500 MB/s
Consumers:            3 groups
Replication factor:   2

Outbound calculation:
  Consumer 1:         500 MB/s
  Consumer 2:         500 MB/s
  Consumer 3:         500 MB/s
  Replication:        500 MB/s
                      ─────────
Total outbound:       2000 MB/s

10 Gbps NIC capacity: 1000 MB/s per broker

Scenario A: 2 brokers
  Per-broker outbound: 1000 MB/s
  Network saturated! ✗

Scenario B: 4 brokers
  Per-broker outbound: 500 MB/s
  Network at 50% utilization ✓
```

**Balancing all factors:**

```
Example cluster sizing:
───────────────────────
Requirement:        10 TB retention, RF=3, 500k partitions

Disk capacity:      5 brokers (6 TB each)
Replica capacity:   36 brokers (14k replicas each)  ← Limiting factor!
Network capacity:   4 brokers (10 Gbps each)

Final decision:     36 brokers
  Provides:         216 TB total disk (more than needed)
  Handles:          1M replicas at capacity
  Network:          Comfortable headroom
```

> **💡 Insight**
>
> Cluster sizing isn't one-dimensional. Calculate requirements across all four factors and choose the most constrained resource. It's common for partition count to force larger clusters than capacity alone would suggest. Plan for the bottleneck, not the average.

### 8.2. Broker Configuration

Only two parameters are **required** to form a multi-broker cluster:

#### Requirement 1: Identical zookeeper.connect

**All brokers must point to the same ZooKeeper ensemble:**

```
Broker 1 config:
zookeeper.connect=zoo1:2181,zoo2:2181,zoo3:2181/kafka-prod

Broker 2 config:
zookeeper.connect=zoo1:2181,zoo2:2181,zoo3:2181/kafka-prod

Broker 3 config:
zookeeper.connect=zoo1:2181,zoo2:2181,zoo3:2181/kafka-prod

Result: All brokers see the same cluster metadata ✓

Misconfiguration:
─────────────────
Broker 1: zookeeper.connect=zoo1:2181/kafka-cluster-1
Broker 2: zookeeper.connect=zoo1:2181/kafka-cluster-2

Result: Two separate clusters! ✗
```

#### Requirement 2: Unique broker.id

**Each broker must have a unique integer ID:**

```
Correct configuration:
──────────────────────
kafka1.example.com:  broker.id=1
kafka2.example.com:  broker.id=2
kafka3.example.com:  broker.id=3

Incorrect configuration:
────────────────────────
kafka1.example.com:  broker.id=1
kafka2.example.com:  broker.id=1  ← Duplicate!

Second broker startup:
  [ERROR] Broker 1 is already registered in ZooKeeper
  [ERROR] Failed to start broker
```

**That's it!** These two settings create a cluster. Additional replication settings are covered in Chapter 7.

---

## 9. OS Tuning

Linux kernel defaults are general-purpose. Kafka-specific tuning can significantly improve performance.

**In plain English:** OS tuning is like adjusting your car's suspension for racing - the factory settings work fine for grocery shopping, but you can do better for specific use cases.

Changes are typically made in `/etc/sysctl.conf`. Consult your Linux distribution documentation for details.

### 9.1. Virtual Memory

#### vm.swappiness

**What it controls:** How aggressively the kernel swaps memory to disk.

**Default:** 60 (on a scale of 0-100)

**Recommended:** 1

**Why it matters:**

```
Swapping workflow:
──────────────────
1. System runs low on RAM
2. Kernel moves memory pages to swap (on disk)
3. Application accesses swapped page
4. Kernel reads page from disk (10ms+ delay)
5. Application continues (with massive latency spike)

For Kafka:
  - Page cache evicted to swap
  - Consumer reads require disk I/O instead of memory
  - Latency increases 100-1000×
```

**Configuration:**

```bash
# /etc/sysctl.conf
vm.swappiness=1
```

**Why 1 instead of 0?**

```
Kernel version < 3.5-rc1:
  vm.swappiness=0 → Swap only under memory pressure

Kernel version ≥ 3.5-rc1:
  vm.swappiness=0 → NEVER swap (can cause OOM kills)
  vm.swappiness=1 → Swap only to avoid OOM

Setting to 1 is safer across kernel versions
```

#### vm.dirty_background_ratio

**What it controls:** Percentage of RAM that can be dirty (modified, not yet written to disk) before background flushing starts.

**Default:** 10

**Recommended:** 5

**Why it matters:**

```
Without background flushing:
────────────────────────────
1. Applications write data (stays in RAM)
2. RAM fills with dirty pages
3. Synchronous flush required (application blocks)
4. Severe latency spike

With background flushing:
─────────────────────────
1. Applications write data (stays in RAM)
2. At 5% dirty pages, background flush starts
3. Steady write stream to disk
4. Smooth performance
```

**Configuration:**

```bash
# /etc/sysctl.conf
vm.dirty_background_ratio=5
```

**Calculation example:**

```
System with 64 GB RAM:
──────────────────────
vm.dirty_background_ratio=5
  → Background flush starts at: 64 GB × 0.05 = 3.2 GB dirty
```

#### vm.dirty_ratio

**What it controls:** Percentage of RAM that can be dirty before **synchronous** flushing (application blocks).

**Default:** 20

**Recommended:** 60-80

**Why increase it?**

```
Scenario: Burst traffic
───────────────────────
64 GB RAM system:

With vm.dirty_ratio=20:
  Max dirty pages: 12.8 GB
  Burst writes 15 GB
  → Synchronous flush at 12.8 GB (blocks application)

With vm.dirty_ratio=60:
  Max dirty pages: 38.4 GB
  Burst writes 15 GB
  → All buffered, no blocking
```

**Trade-off:**

```
Higher dirty_ratio:
  Pros: Handles bursts better, fewer sync flushes
  Cons: More data at risk during power loss

Mitigation: Use replication
  Kafka's replication protects against data loss
  → Safe to increase dirty_ratio
```

**Configuration:**

```bash
# /etc/sysctl.conf
vm.dirty_ratio=60
```

**Monitoring dirty pages:**

```bash
cat /proc/vmstat | egrep "dirty|writeback"

Output:
nr_dirty 21845                    ← Currently dirty pages
nr_writeback 0                    ← Currently being written
nr_dirty_threshold 32715981       ← Dirty ratio threshold
nr_dirty_background_threshold 2726331  ← Background ratio threshold
```

> **💡 Insight**
>
> Virtual memory tuning is crucial for Kafka's performance. The settings optimize for Kafka's write-heavy, sequential I/O pattern while preventing swap-induced latency spikes. These settings are safe for most Kafka deployments due to replication protecting against data loss.

#### vm.max_map_count

**What it controls:** Maximum number of memory-mapped file regions a process can have.

**Default:** 65530 (varies by distribution)

**Recommended:** 400,000-600,000 for Kafka

**Why it matters:**

```
Kafka uses memory-mapped files for:
───────────────────────────────────
1. Log segment files
2. Index files
3. Network connections

Calculation:
────────────
Partitions:          10,000
Avg segment size:    1 GB
Avg partition size:  100 GB

Log segments: 10,000 partitions × 100 segments = 1,000,000 segments
Index files:  1,000,000 (one per segment)
Connections:  10,000 (clients + inter-broker)
              ─────────
Total maps:   ~2,010,000

Default 65,530 is far too low!
```

**Configuration:**

```bash
# /etc/sysctl.conf
vm.max_map_count=600000
```

#### vm.overcommit_memory

**What it controls:** How the kernel handles memory allocation requests.

**Default:** 0 (heuristic overcommit)

**Recommended:** 0 (keep default)

**Settings explained:**

```
vm.overcommit_memory=0 (heuristic):
───────────────────────────────────
Kernel intelligently decides memory allocation
Considers available RAM, swap, and system state
Recommended for Kafka ✓

vm.overcommit_memory=1 (always overcommit):
───────────────────────────────────────────
Always allow memory requests (can lead to OOM)
Risky for Kafka ✗

vm.overcommit_memory=2 (strict accounting):
───────────────────────────────────────────
Never overcommit (very conservative)
Can cause allocation failures for Kafka ✗
```

**Configuration:**

```bash
# /etc/sysctl.conf
vm.overcommit_memory=0
```

### 9.2. Disk

#### Filesystem selection

**In plain English:** Choosing between Ext4 and XFS is like choosing between automatic and manual transmission - both work, but one is better suited for high performance.

**Ext4 vs. XFS:**

| Feature | Ext4 | XFS |
|---------|------|-----|
| Default for | Older distributions | Modern distributions |
| Performance (default config) | Good | Better |
| Tuning required | Significant | Minimal |
| Delayed allocation | Less safe | Safer |
| Large file handling | Good | Excellent |
| Concurrent writes | Good | Better |

**Recommended:** XFS for Kafka

**Why XFS?**

```
XFS advantages for Kafka:
─────────────────────────
1. Better write batching (matches Kafka's pattern)
2. Safer delayed allocation algorithm
3. Better large file performance
4. Self-tuning (less manual configuration)
5. Better concurrent write handling
```

**Formatting disks for Kafka:**

```bash
# Create XFS filesystem
mkfs.xfs /dev/sdb

# Mount with recommended options
mount -o noatime,largeio /dev/sdb /disk1/kafka-logs
```

#### Mount options

**noatime - Critical for performance**

**What it does:** Disables access time (atime) updates when files are read.

**Impact:**

```
Without noatime:
────────────────
1. Consumer reads log segment
2. Filesystem updates file atime (disk write)
3. Repeat for every file access

Result: Massive write overhead for read-heavy workloads ✗

With noatime:
─────────────
1. Consumer reads log segment
2. No atime update
3. Only actual writes go to disk

Result: Eliminates unnecessary disk writes ✓
```

**Configuration:**

```bash
# /etc/fstab
/dev/sdb  /disk1/kafka-logs  xfs  noatime,largeio  0  2
```

**Alternative: relatime**

If you need atime for other applications:

```
relatime: Only update atime if:
  - File is modified (mtime changes), OR
  - Current atime is older than 24 hours

Reduces writes while maintaining some atime tracking
```

**largeio - Improves large write efficiency**

Optimizes I/O for large sequential writes (Kafka's access pattern).

**Complete fstab example:**

```bash
# /etc/fstab
UUID=xxx  /                    ext4    defaults            1  1
UUID=yyy  /disk1/kafka-logs    xfs     noatime,largeio     0  2
UUID=zzz  /disk2/kafka-logs    xfs     noatime,largeio     0  2
UUID=www  /disk3/kafka-logs    xfs     noatime,largeio     0  2
```

### 9.3. Networking

**In plain English:** Network tuning increases the size of the "pipe" between Kafka and clients - bigger pipes mean more data flows without congestion.

#### Socket buffer sizes

**What they control:** Memory allocated per socket for send and receive operations.

**Default settings (typically):**

```
Send buffer:    ~16 KB default, ~2 MB max
Receive buffer: ~16 KB default, ~2 MB max
```

**Recommended for Kafka:**

```
Default buffer:  128 KB
Maximum buffer:  2 MB
```

**Configuration:**

```bash
# /etc/sysctl.conf

# General socket defaults
net.core.wmem_default=131072  # 128 KB send buffer default
net.core.rmem_default=131072  # 128 KB receive buffer default
net.core.wmem_max=2097152     # 2 MB send buffer max
net.core.rmem_max=2097152     # 2 MB receive buffer max
```

#### TCP socket buffers

**Separate from general socket buffers:**

```bash
# /etc/sysctl.conf

# TCP socket buffers: min default max
net.ipv4.tcp_wmem=4096 65536 2048000  # Send: 4KB min, 64KB default, 2MB max
net.ipv4.tcp_rmem=4096 65536 2048000  # Recv: 4KB min, 64KB default, 2MB max
```

**Format:** `min default max`

| Value | Purpose |
|-------|---------|
| min (4 KB) | Smallest buffer allocation |
| default (64 KB) | Initial size for new connections |
| max (2 MB) | Maximum the buffer can grow to |

**Important:** TCP max cannot exceed `net.core.wmem_max` / `net.core.rmem_max`.

#### TCP window scaling

**What it does:** Allows TCP windows larger than 64 KB for high-bandwidth connections.

```bash
# /etc/sysctl.conf
net.ipv4.tcp_window_scaling=1
```

**Why it matters:**

```
Without window scaling (64 KB max window):
──────────────────────────────────────────
Max throughput on 100ms latency connection:
  64 KB ÷ 0.1s = 640 KB/s = ~5 Mbps

With window scaling (2 MB window):
──────────────────────────────────
Max throughput on 100ms latency connection:
  2 MB ÷ 0.1s = 20 MB/s = ~160 Mbps

Essential for high-latency or high-bandwidth scenarios
```

#### TCP connection backlog

**What it controls:** Number of pending connections the kernel can queue.

```bash
# /etc/sysctl.conf

# SYN backlog (new connections being established)
net.ipv4.tcp_max_syn_backlog=2048

# General network device backlog (packet processing queue)
net.core.netdev_max_backlog=2000
```

**Why increase these?**

```
Default tcp_max_syn_backlog=1024:
──────────────────────────────────
Scenario: 1500 clients connecting simultaneously
  First 1024: Queued successfully
  Next 476:   Connection refused ✗

Increased tcp_max_syn_backlog=2048:
───────────────────────────────────
  All 1500:   Queued successfully ✓
```

**Complete network tuning example:**

```bash
# /etc/sysctl.conf

# Socket buffers
net.core.wmem_default=131072
net.core.rmem_default=131072
net.core.wmem_max=2097152
net.core.rmem_max=2097152

# TCP buffers
net.ipv4.tcp_wmem=4096 65536 2048000
net.ipv4.tcp_rmem=4096 65536 2048000

# TCP window scaling
net.ipv4.tcp_window_scaling=1

# Connection backlogs
net.ipv4.tcp_max_syn_backlog=2048
net.core.netdev_max_backlog=2000
```

**Apply settings:**

```bash
# Reload sysctl configuration
sysctl -p /etc/sysctl.conf
```

> **💡 Insight**
>
> Network tuning is universally beneficial for high-throughput applications. These settings are standard recommendations for web servers, databases, and message brokers - not Kafka-specific. They allow the kernel to buffer more data, reducing packet loss and improving throughput for high-volume connections.

---

## 10. Production Concerns

### 10.1. Garbage Collector Options

**In plain English:** Java garbage collection is like cleaning your house - you can do it all at once (freezing everything) or clean room-by-room (G1GC) with minimal disruption.

**Kafka's default GC:**

Kafka defaults to **concurrent mark-and-sweep (CMS)** for backward compatibility with older JVMs. This is outdated.

**Recommended: G1GC (Garbage-First Garbage Collector)**

**Why G1GC?**

```
Traditional GC (CMS):
─────────────────────
Collects entire heap
→ Long pause times as heap grows
→ Manual tuning required

G1GC:
─────
Segments heap into regions
Collects regions with most garbage first
→ Consistent pause times
→ Minimal tuning needed
→ Handles large heaps gracefully
```

**G1GC configuration parameters:**

**1. MaxGCPauseMillis**

**What it does:** Target pause time per garbage collection cycle.

**Default:** 200 milliseconds

**Recommended for Kafka:** 20 milliseconds

```
MaxGCPauseMillis=200:
─────────────────────
G1GC schedules collection to take ~200ms each cycle
Suitable for batch applications

MaxGCPauseMillis=20:
────────────────────
G1GC schedules collection to take ~20ms each cycle
Better for low-latency streaming applications like Kafka
```

**2. InitiatingHeapOccupancyPercent**

**What it does:** Heap usage percentage that triggers garbage collection.

**Default:** 45%

**Recommended for Kafka:** 35%

```
IHOP=45:
────────
Collection starts when heap reaches 45% usage

IHOP=35:
────────
Collection starts when heap reaches 35% usage
Runs more frequently, prevents large collections
```

**Complete G1GC configuration:**

```bash
# Set environment variable before starting Kafka
export KAFKA_JVM_PERFORMANCE_OPTS="-server -Xmx6g -Xms6g \
  -XX:MetaspaceSize=96m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=20 \
  -XX:InitiatingHeapOccupancyPercent=35 \
  -XX:G1HeapRegionSize=16M \
  -XX:MinMetaspaceFreeRatio=50 \
  -XX:MaxMetaspaceFreeRatio=80 \
  -XX:+ExplicitGCInvokesConcurrent"

# Start Kafka broker
/usr/local/kafka/bin/kafka-server-start.sh -daemon \
  /usr/local/kafka/config/server.properties
```

**Parameter explanations:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `-Xmx6g` | 6 GB | Maximum heap size |
| `-Xms6g` | 6 GB | Initial heap size (same as max for consistency) |
| `-XX:+UseG1GC` | Enabled | Use G1 garbage collector |
| `-XX:MaxGCPauseMillis` | 20 | Target 20ms pause times |
| `-XX:InitiatingHeapOccupancyPercent` | 35 | Start collection at 35% heap usage |
| `-XX:G1HeapRegionSize` | 16M | Size of G1 heap regions |

**Heap size selection:**

```
Typical broker memory:
──────────────────────
Total RAM:   64 GB
JVM heap:    5-8 GB  (conservative)
Page cache:  56-59 GB (most memory)

Why small heap?
  - Kafka doesn't hold messages in heap
  - Only connection state and buffers in heap
  - Large page cache more valuable than large heap
```

> **💡 Insight**
>
> G1GC is a significant improvement over CMS for Kafka workloads. The tuning parameters here are battle-tested across thousands of Kafka deployments. Don't over-complicate garbage collection tuning - these settings work well for the vast majority of workloads.

### 10.2. Datacenter Layout

**In plain English:** Datacenter layout is like fire safety - you don't want all your backup generators on the same electrical circuit.

**Rack awareness:**

Kafka can distribute partition replicas across racks/fault domains to survive infrastructure failures.

**Configuration:**

```
# broker 1 (rack A)
broker.rack=rack-a

# broker 2 (rack B)
broker.rack=rack-b

# broker 3 (rack C)
broker.rack=rack-c
```

**How it works:**

```
Without rack awareness:
───────────────────────
Topic "orders" with RF=3 might assign:
  Partition 0: Replicas on brokers 1, 2, 3 (all in rack A!)

Rack A power failure → All replicas lost ✗

With rack awareness:
────────────────────
Topic "orders" with RF=3 assigns:
  Partition 0: Replicas on brokers 1 (rack A), 2 (rack B), 3 (rack C)

Any single rack failure → 2 replicas survive ✓
```

**Cloud environments:**

```
AWS:
  broker.rack=us-east-1a    (availability zone)
  broker.rack=us-east-1b
  broker.rack=us-east-1c

Azure:
  broker.rack=fault-domain-1
  broker.rack=fault-domain-2
  broker.rack=fault-domain-3
```

**Important limitation:**

Rack awareness only applies to **newly created partitions**. Existing partitions are not automatically rebalanced.

**Maintaining rack awareness over time:**

Use rebalancing tools like **Cruise Control** (see Appendix B) to maintain rack distribution as partitions are reassigned.

**Physical datacenter best practices:**

```
Recommended setup:
──────────────────
1. Each broker in a different rack
2. Dual power connections (separate circuits)
3. Dual network switches with bonded interfaces
4. Isolated cooling zones
5. Physical security separation

Minimum acceptable:
───────────────────
1. Brokers spread across ≥3 racks
2. Dual power connections
3. Dual network switches
```

> **💡 Insight**
>
> Rack awareness is free insurance - it costs nothing to configure but saves you during infrastructure failures. Always set `broker.rack` in production deployments. Combined with appropriate replication factor, it protects against common datacenter failures: PDU failures, top-of-rack switch failures, cooling zone issues.

### 10.3. Colocating Applications on ZooKeeper

**In plain English:** Sharing ZooKeeper is like sharing a phone line - it works until someone hogs the line during an important call.

**ZooKeeper usage patterns:**

```
Kafka's ZooKeeper usage:
────────────────────────
Writes: Only on cluster membership changes (infrequent)
Reads:  Periodic metadata queries (low volume)

Traffic level: Minimal (typically)
```

**Sharing ZooKeeper across Kafka clusters:**

**Acceptable:**

```
Single ZooKeeper ensemble, multiple Kafka clusters:
───────────────────────────────────────────────────
zk1:2181,zk2:2181,zk3:2181/kafka-cluster-1
zk1:2181,zk2:2181,zk3:2181/kafka-cluster-2
zk1:2181,zk2:2181,zk3:2181/kafka-cluster-3

Using chroot paths isolates clusters
Common and recommended ✓
```

**Sharing with other applications:**

**Risky:**

```
Scenario: ZooKeeper shared with coordination-heavy app
──────────────────────────────────────────────────────
App performs heavy write traffic
  → ZooKeeper latency increases
  → Kafka broker timeouts
  → Multiple brokers lose ZooKeeper connection
  → Controller failover
  → Partition unavailability

Hours after incident:
  → Subtle errors in partition assignment
  → Failed controlled shutdowns
  → Operational complexity
```

**When sharing is acceptable:**

```
Other application must be:
──────────────────────────
1. Low write frequency (similar to Kafka)
2. Tolerant of ZooKeeper latency
3. Non-critical (can be isolated if issues arise)

Still recommended: Dedicated ZooKeeper ensemble for Kafka
```

**Legacy consumer considerations:**

**Deprecated but still seen:**

```
Old Kafka consumers (pre-0.9.0.0):
──────────────────────────────────
Stored offsets in ZooKeeper
Committed every minute (configurable)

Problem:
  Many consumers × Many partitions × Frequent commits
  = High ZooKeeper write load

Example:
  10 consumer groups
  × 100 partitions each
  × 1 commit/minute
  = 1,000 writes/minute to ZooKeeper

Modern Kafka consumers (0.9.0.0+):
──────────────────────────────────
Store offsets in Kafka itself (__consumer_offsets topic)
No ZooKeeper dependency for offset storage ✓
```

**Best practices:**

```
1. Use dedicated ZooKeeper ensemble for Kafka
2. If sharing across Kafka clusters, use chroot paths
3. Avoid sharing with non-Kafka applications
4. Upgrade legacy consumers to use Kafka for offsets
5. Monitor ZooKeeper latency and timeouts
```

**ZooKeeper removal roadmap:**

```
Kafka 2.8.0: Early access ZooKeeper-less mode (KIP-500)
Future:       ZooKeeper fully replaced by Kafka Raft (KRaft)

Long-term: ZooKeeper dependency eliminated entirely
```

> **💡 Insight**
>
> ZooKeeper is Kafka's Achilles heel - it's a single point of failure for cluster coordination. While it's tempting to consolidate infrastructure by sharing ZooKeeper, the operational risk usually outweighs the cost savings. Dedicate a ZooKeeper ensemble to Kafka for production deployments.

---

## 11. Summary

**What we learned:**

**1. Installation Foundation**
- Linux is the recommended OS for production Kafka
- Java 8 or 11 required for Kafka and ZooKeeper
- ZooKeeper stores cluster metadata (being phased out over time)

**2. ZooKeeper Setup**
- Standalone servers work for development
- Production requires 3 or 5-node ensembles (odd numbers)
- Chroot paths isolate multiple clusters on shared ZooKeeper
- Quorum requirement means N servers tolerate (N-1)/2 failures

**3. Kafka Broker Installation**
- Install Kafka, configure `server.properties`, start broker
- Verify with create/produce/consume workflow
- Use `--bootstrap-server` for all CLI tools (not `--zookeeper`)

**4. Configuration Essentials**
- **broker.id**: Unique identifier per broker
- **listeners**: Network interfaces and ports
- **zookeeper.connect**: ZooKeeper ensemble location
- **log.dirs**: Where message data is stored
- **num.partitions**: Default partition count for new topics
- **default.replication.factor**: Default replication (recommended: 3)
- **log.retention.ms**: How long to keep messages (time-based)
- **min.insync.replicas**: Minimum replicas for durable writes (recommended: 2)

**5. Hardware Selection**
- **Disk**: HDDs acceptable for most workloads, SSDs for low latency
- **Memory**: Large page cache more valuable than large JVM heap
- **Network**: 10 Gbps NICs minimum for production
- **CPU**: Usually not a bottleneck until very large scale

**6. Cloud Deployments**
- **Azure**: Separate compute and storage, Premium SSD recommended
- **AWS**: Choose between EBS (persistent) and Instance Store (performance)
- Both: Use availability zones/fault domains for replication distribution

**7. Cluster Configuration**
- Size based on disk capacity, replica count, CPU, or network - whichever constrains first
- All brokers must share `zookeeper.connect` and have unique `broker.id`
- Recommended: ≥3 brokers for fault tolerance

**8. OS Tuning**
- **Virtual memory**: Disable swap, tune dirty page ratios
- **Disk**: Use XFS filesystem with `noatime` mount option
- **Network**: Increase socket buffers, enable TCP window scaling

**9. Production Readiness**
- Use G1GC with `MaxGCPauseMillis=20` and `IHOP=35`
- Configure `broker.rack` for rack awareness
- Dedicate ZooKeeper ensemble to Kafka (don't share with other apps)

**Key Takeaway:**

Proper installation and configuration form the foundation for a reliable, high-performance Kafka deployment. Each decision - from hardware selection to OS tuning to cluster sizing - compounds into the system's overall capabilities. Invest time upfront in understanding these choices to avoid painful migrations later.

---

**Previous:** [Chapter 1: Meet Kafka](./chapter1.md) | **Next:** [Chapter 3: Kafka Producers →](./chapter3.md)
