# 12. Administering Kafka

> **In plain English:** Administering Kafka is like being a city traffic controller - you manage the flow of data (traffic), adjust routes (partitions), monitor congestion (lag), and keep everything running smoothly without shutting down the entire system.
>
> **In technical terms:** Kafka administration involves using CLI tools to manage topics, consumer groups, configurations, and partitions while the cluster is running, ensuring optimal performance and reliability.
>
> **Why it matters:** A well-administered Kafka cluster can handle billions of messages per day reliably. Poor administration leads to data loss, consumer lag, unbalanced loads, and system outages.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Topic Operations](#2-topic-operations)
   - 2.1. [Creating Topics](#21-creating-topics)
   - 2.2. [Listing Topics](#22-listing-topics)
   - 2.3. [Describing Topics](#23-describing-topics)
   - 2.4. [Adding Partitions](#24-adding-partitions)
   - 2.5. [Deleting Topics](#25-deleting-topics)
3. [Consumer Group Management](#3-consumer-group-management)
   - 3.1. [Listing and Describing Groups](#31-listing-and-describing-groups)
   - 3.2. [Deleting Groups](#32-deleting-groups)
   - 3.3. [Managing Offsets](#33-managing-offsets)
4. [Dynamic Configuration Changes](#4-dynamic-configuration-changes)
   - 4.1. [Topic Configurations](#41-topic-configurations)
   - 4.2. [Client and User Configurations](#42-client-and-user-configurations)
   - 4.3. [Broker Configurations](#43-broker-configurations)
   - 4.4. [Viewing and Removing Overrides](#44-viewing-and-removing-overrides)
5. [Producing and Consuming](#5-producing-and-consuming)
   - 5.1. [Console Producer](#51-console-producer)
   - 5.2. [Console Consumer](#52-console-consumer)
6. [Partition Management](#6-partition-management)
   - 6.1. [Preferred Replica Election](#61-preferred-replica-election)
   - 6.2. [Reassigning Partitions](#62-reassigning-partitions)
   - 6.3. [Changing Replication Factor](#63-changing-replication-factor)
7. [Advanced Operations](#7-advanced-operations)
   - 7.1. [Dumping Log Segments](#71-dumping-log-segments)
   - 7.2. [Replica Verification](#72-replica-verification)
   - 7.3. [Other Tools](#73-other-tools)
8. [Unsafe Operations](#8-unsafe-operations)
   - 8.1. [Moving the Controller](#81-moving-the-controller)
   - 8.2. [Removing Stuck Deletions](#82-removing-stuck-deletions)
   - 8.3. [Manual Topic Deletion](#83-manual-topic-deletion)
9. [Summary](#9-summary)

---

## 1. Introduction

Managing a Kafka cluster requires specialized tooling to perform administrative changes to topics, configurations, and cluster operations. Kafka provides several command-line interface (CLI) utilities implemented as Java classes, with shell scripts that call these classes properly.

**In plain English:** Think of Kafka CLI tools as your control panel - they let you create topics, monitor consumer health, adjust configurations, and troubleshoot issues without writing code.

> **Security Warning**
>
> Default Kafka configurations do NOT restrict CLI tool usage. Anyone with access to the server can make changes without authentication. Always restrict access to administrators only to prevent unauthorized modifications.

**Tool location:** Throughout this chapter, all tools are located in `/usr/local/kafka/bin/`. The examples assume you're either in this directory or have added it to your `$PATH`.

> **Version Compatibility**
>
> CLI tools have version dependencies with the Kafka brokers. Always use tools that match your broker version. The safest approach: run tools directly on the Kafka brokers using the deployed version.

---

## 2. Topic Operations

The `kafka-topics.sh` tool provides easy access to most topic operations: create, modify, delete, and list topics in the cluster.

**Connection requirement:** All commands require the `--bootstrap-server` option with the cluster connection string. In these examples, we use `localhost:9092`.

### 2.1. Creating Topics

**In plain English:** Creating a topic is like setting up a new filing system - you define how many drawers (partitions) it has and how many backup copies (replicas) to maintain.

#### Required Arguments

When creating a topic, three arguments are required:

1. `--topic` - The name of the topic
2. `--replication-factor` - Number of replicas per partition
3. `--partitions` - Number of partitions

**Basic syntax:**
```bash
kafka-topics.sh --bootstrap-server <connection-string>:<port> \
  --create --topic <string> \
  --replication-factor <integer> \
  --partitions <integer>
```

**Example - Create a topic with 8 partitions and 2 replicas:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic my-topic --replication-factor 2 --partitions 8

Created topic "my-topic".
```

> **Topic Naming Best Practices**
>
> **Allowed characters:** Alphanumeric, underscores, dashes, periods
>
> **Avoid periods:** Kafka metrics convert periods to underscores (`topic.1` becomes `topic_1`), which can cause name conflicts
>
> **Avoid double underscores:** Topics starting with `__` are reserved for internal Kafka operations (like `__consumer_offsets`)

#### Rack-Aware Replica Assignment

By default, Kafka distributes replicas across different racks for fault tolerance. To disable this:

```bash
kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic my-topic --replication-factor 2 --partitions 8 \
  --disable-rack-aware
```

> **Automation Tip**
>
> Use `--if-not-exists` in automation to prevent errors if the topic already exists:
> ```bash
> kafka-topics.sh --bootstrap-server localhost:9092 --create \
>   --topic my-topic --replication-factor 2 --partitions 8 \
>   --if-not-exists
> ```

### 2.2. Listing Topics

**In plain English:** Get a simple list of all topics in your cluster - like viewing all folders in a directory.

**Basic listing:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --list

__consumer_offsets
my-topic
other-topic
```

**Exclude internal topics:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --list --exclude-internal

my-topic
other-topic
```

### 2.3. Describing Topics

**In plain English:** Get detailed information about topics - like looking inside a folder to see its size, contents, and organization.

**Describe a specific topic:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic my-topic

Topic: my-topic	PartitionCount: 8	ReplicationFactor: 2	Configs: segment.bytes=1073741824
	Topic: my-topic	Partition: 0	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: my-topic	Partition: 1	Leader: 0	Replicas: 0,1	Isr: 0,1
	Topic: my-topic	Partition: 2	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: my-topic	Partition: 3	Leader: 0	Replicas: 0,1	Isr: 0,1
	Topic: my-topic	Partition: 4	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: my-topic	Partition: 5	Leader: 0	Replicas: 0,1	Isr: 0,1
	Topic: my-topic	Partition: 6	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: my-topic	Partition: 7	Leader: 0	Replicas: 0,1	Isr: 0,1
```

**Understanding the output:**
```
Output Breakdown
────────────────
Leader:    Broker handling reads/writes for this partition
Replicas:  Brokers storing copies (leader + followers)
Isr:       In-Sync Replicas (replicas caught up with leader)
```

#### Useful Filtering Options

**Topics with custom configurations:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topics-with-overrides
```

**Under-replicated partitions (URPs):**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --under-replicated-partitions
```

> **Understanding URPs**
>
> Under-replicated partitions occur when one or more replicas aren't in sync with the leader. This isn't always bad - cluster maintenance, deployments, and rebalances cause temporary URPs. However, sustained URPs indicate problems.

**Partitions at minimum ISR:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --at-min-isr-partitions
```

**Example output (broker 1 is down):**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --at-min-isr-partitions

Topic: my-topic Partition: 0    Leader: 0       Replicas: 0,1   Isr: 0
Topic: my-topic Partition: 1    Leader: 0       Replicas: 0,1   Isr: 0
Topic: my-topic Partition: 2    Leader: 0       Replicas: 0,1   Isr: 0
...
```

> **Danger: Below Minimum ISR**
>
> Use `--under-min-isr-partitions` to find partitions below the configured minimum ISRs. These partitions are in READ-ONLY mode and cannot accept new writes.

**Unavailable partitions (critical):**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --describe --unavailable-partitions
```

> **Critical Alert**
>
> Unavailable partitions have no leader. They are OFFLINE and inaccessible to producers and consumers. This requires immediate attention.

### 2.4. Adding Partitions

**In plain English:** Adding partitions is like opening more checkout lanes at a store - it increases throughput by allowing more parallel processing.

**Common reasons to add partitions:**
- Horizontally scale a topic across more brokers
- Reduce per-partition throughput
- Allow more consumers in a consumer group (one partition per consumer max)

**Example - Increase from 8 to 16 partitions:**
```bash
# Increase partitions
kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter --topic my-topic --partitions 16

# Verify the change
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic my-topic

Topic: my-topic	PartitionCount: 16	ReplicationFactor: 2	Configs: segment.bytes=1073741824
	Topic: my-topic	Partition: 0	Leader: 1	Replicas: 1,0	Isr: 1,0
	Topic: my-topic	Partition: 1	Leader: 0	Replicas: 0,1	Isr: 0,1
	...
	Topic: my-topic	Partition: 15	Leader: 0	Replicas: 0,1	Isr: 0,1
```

> **Warning: Keyed Topics**
>
> Topics with keyed messages use partition count for key routing:
> ```
> partition = hash(key) % partition_count
> ```
>
> Changing partition count changes this mapping, breaking consumer ordering assumptions. For keyed topics:
> - Set partition count ONCE when creating the topic
> - Avoid resizing later
>
> **Why this matters:** If key "user-123" was always in partition 3, adding partitions might move it to partition 7, breaking consumers that expect ordered messages per user.

#### Why You Can't Reduce Partitions

**In plain English:** You can add partitions but never remove them. Why? Deleting a partition would delete data, and redistributing that data would break message ordering.

**Alternative approaches:**
1. Delete the topic and recreate it (loses all data)
2. Create a new version (e.g., `my-topic-v2`) and migrate producers

### 2.5. Deleting Topics

**In plain English:** Deleting removes a topic entirely, freeing disk space, filehandles, memory, and controller metadata.

**Prerequisites:**
- Brokers must have `delete.topic.enable = true`
- If set to `false`, deletion requests are ignored

**Delete a topic:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic my-topic

Note: This will have no impact if delete.topic.enable is not set to true.
```

> **Data Loss Warning**
>
> Deleting a topic deletes ALL its messages permanently. This is NOT reversible. Execute with caution.

**Understanding asynchronous deletion:**
```
Deletion Process
────────────────
1. Topic marked for deletion (immediate)
2. Controller notifies brokers (when queue clears)
3. Brokers invalidate metadata
4. Files deleted from disk (can take time on large topics)
```

> **Best Practice**
>
> Delete only 1-2 topics at a time. Wait for completion before deleting more. The controller handles deletions sequentially and can become overwhelmed.

**Verify deletion:**
```bash
# List should not show the deleted topic
kafka-topics.sh --bootstrap-server localhost:9092 --list
```

---

## 3. Consumer Group Management

Consumer groups coordinate multiple consumers reading from topics. The `kafka-consumer-groups.sh` tool manages these groups.

**In plain English:** Consumer groups are like teams of workers. This tool lets you see what each team is doing, how far behind they are, and reset their position if needed.

### 3.1. Listing and Describing Groups

**List all consumer groups:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

console-consumer-95554
console-consumer-9581
my-consumer
```

> **Console Consumer Groups**
>
> Ad hoc consumers using `kafka-console-consumer.sh` appear as `console-consumer-<generated_id>`.

**Describe a specific group:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group my-consumer

GROUP        TOPIC      PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG  CONSUMER-ID                                    HOST          CLIENT-ID
my-consumer  my-topic   0          2               4               2    consumer-1-029af89c-873c-4751-a720-cefd41a669d6  /127.0.0.1    consumer-1
my-consumer  my-topic   1          2               3               1    consumer-1-029af89c-873c-4751-a720-cefd41a669d6  /127.0.0.1    consumer-1
my-consumer  my-topic   2          2               3               1    consumer-2-42c1abd4-e3b2-425d-a8bb-e1ea49b29bb2  /127.0.0.1    consumer-2
```

**Understanding the fields:**

| Field | Description |
|-------|-------------|
| **GROUP** | Consumer group name |
| **TOPIC** | Topic being consumed |
| **PARTITION** | Partition ID being consumed |
| **CURRENT-OFFSET** | Next offset to be consumed (consumer's position) |
| **LOG-END-OFFSET** | Latest offset on broker (high-water mark) |
| **LAG** | Difference between current and end offset (how far behind) |
| **CONSUMER-ID** | Unique ID based on client-id |
| **HOST** | Address of consumer host |
| **CLIENT-ID** | String identifying the consumer application |

> **Monitoring Tip**
>
> **LAG** is the most important metric. It shows how far behind consumers are:
> ```
> LAG = 0         → Consumer is caught up
> LAG = 100       → 100 messages behind
> LAG = growing   → Consumer can't keep up (problem!)
> ```

### 3.2. Deleting Groups

**In plain English:** Deleting a consumer group removes it and all stored offsets. It's like clearing a team's progress tracker.

**Prerequisites:**
- All consumers in the group must be shut down
- Group must have no active members

**Delete entire group:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --delete --group my-consumer

Deletion of requested consumer groups ('my-consumer') was successful.
```

**Delete offsets for a single topic:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --delete --group my-consumer --topic my-topic
```

> **Common Error**
>
> If you see "The group is not empty", consumers are still running. Shut down all consumers first.

### 3.3. Managing Offsets

**In plain English:** Offset management lets you rewind or fast-forward consumer position - like using a bookmark to return to a specific page in a book.

**Common use cases:**
- Reprocess messages after fixing a bug
- Skip past a corrupted message
- Reset to a specific timestamp

#### Exporting Offsets

**Export to CSV for backup:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --export --group my-consumer --topic my-topic \
  --reset-offsets --to-current --dry-run > offsets.csv

cat offsets.csv

my-topic,0,8905
my-topic,1,8915
my-topic,2,9845
my-topic,3,8072
my-topic,4,8008
my-topic,5,8319
my-topic,6,8102
my-topic,7,12739
```

**CSV format:**
```
<topic-name>,<partition-number>,<offset>
```

> **Important: --dry-run**
>
> The `--dry-run` option exports offsets WITHOUT resetting them. Remove this flag to actually reset offsets.

#### Importing Offsets

**In plain English:** Import offsets to restore or manually set consumer positions.

> **Critical: Stop Consumers First**
>
> All consumers in the group MUST be stopped before importing offsets. Running consumers will overwrite imported offsets.

**Process:**
```
1. Export current offsets (backup)
2. Copy the file
3. Edit copy to desired offsets
4. Stop all consumers
5. Import new offsets
6. Restart consumers
```

**Import offsets:**
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --reset-offsets --group my-consumer \
  --from-file offsets.csv --execute

TOPIC      PARTITION  NEW-OFFSET
my-topic   0          8905
my-topic   1          8915
my-topic   2          9845
my-topic   3          8072
my-topic   4          8008
my-topic   5          8319
my-topic   6          8102
my-topic   7          12739
```

---

## 4. Dynamic Configuration Changes

The `kafka-configs.sh` tool modifies configurations at runtime without restarting brokers or redeploying the cluster.

**In plain English:** Dynamic configs are like adjusting thermostats while the building is occupied - no shutdown required.

**Four entity types:**
1. **Topics** - Individual topic settings
2. **Brokers** - Broker-level settings
3. **Users** - User quotas and limits
4. **Clients** - Client quotas and limits

### 4.1. Topic Configurations

**In plain English:** Override cluster-level defaults for specific topics to accommodate different use cases in a single cluster.

**Basic syntax:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type topics --entity-name <topic-name> \
  --add-config <key>=<value>[,<key>=<value>...]
```

**Example - Set retention to 1 hour:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type topics --entity-name my-topic \
  --add-config retention.ms=3600000

Updated config for topic: "my-topic".
```

#### Common Topic Configurations

| Configuration | Description |
|---------------|-------------|
| `cleanup.policy` | Set to `compact` for log compaction (keep only latest value per key) |
| `compression.type` | Compression when writing to disk: `none`, `gzip`, `snappy`, `zstd`, `lz4` |
| `retention.ms` | How long to retain messages (milliseconds) |
| `retention.bytes` | How much data to retain (bytes) |
| `segment.bytes` | Size of a single log segment |
| `min.insync.replicas` | Minimum replicas that must acknowledge writes |
| `max.message.bytes` | Maximum message size (bytes) |

> **Log Compaction Example**
>
> ```bash
> # Create a topic that keeps only the latest value per key
> kafka-configs.sh --bootstrap-server localhost:9092 \
>   --alter --entity-type topics --entity-name user-profile \
>   --add-config cleanup.policy=compact
> ```
>
> **Use case:** Maintain current state (latest user profile) while discarding historical updates.

### 4.2. Client and User Configurations

**In plain English:** Set quotas to prevent individual clients from overwhelming the cluster - like speed limits on a highway.

**Common configurations:**

| Configuration | Description |
|---------------|-------------|
| `producer_bytes_rate` | Max bytes/sec a client can produce per broker |
| `consumer_bytes_rate` | Max bytes/sec a client can consume per broker |
| `controller_mutations_rate` | Rate limit for create/delete topic operations |
| `request_percentage` | Percentage of request handler threads a client can use |

**Example - Set producer quota:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --add-config "producer_bytes_rate=10485760" \
  --entity-type clients --entity-name my-client-id
```

> **Understanding Per-Broker Quotas**
>
> Quotas are per broker, not cluster-wide:
> ```
> Balanced cluster (5 brokers):
> - Producer quota: 10 MBps per broker
> - Total throughput: 50 MBps (if leadership balanced)
>
> Unbalanced cluster (all leaders on broker 1):
> - Producer quota: 10 MBps per broker
> - Total throughput: 10 MBps (bottleneck!)
> ```
>
> **Key insight:** Maintain balanced partition leadership for quotas to work effectively.

**Combine user and client quotas:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --add-config "controller_mutations_rate=10" \
  --entity-type clients --entity-name <client-id> \
  --entity-type users --entity-name <user-id>
```

> **Client ID vs. Consumer Group**
>
> These are NOT the same:
> - **Client ID:** Set by each consumer instance (can be shared)
> - **Consumer Group:** Coordinates multiple consumers
>
> **Best practice:** Set client ID to match consumer group name for easier tracking and shared quotas.

### 4.3. Broker Configurations

**In plain English:** Override broker defaults to fine-tune individual broker behavior without restarting.

**Key broker configurations:**

**min.insync.replicas**
```bash
# Require at least 2 replicas to acknowledge writes
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type brokers --entity-name 0 \
  --add-config min.insync.replicas=2
```

**unclean.leader.election.enable**
```bash
# Allow unclean leader election (may cause data loss)
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type brokers --entity-name 0 \
  --add-config unclean.leader.election.enable=true
```

> **When to Enable Unclean Elections**
>
> **Default:** `false` (prevent data loss)
> **Enable when:**
> - Availability more important than consistency
> - Short-term to unstick a cluster
> - Acceptable to lose messages
>
> **Disable immediately** after recovering from the incident.

**max.connections**
```bash
# Limit total connections to a broker
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type brokers --entity-name 0 \
  --add-config max.connections=1000
```

### 4.4. Viewing and Removing Overrides

**Describe configuration overrides:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --describe --entity-type topics --entity-name my-topic

Configs for topics:my-topic are
retention.ms=3600000
```

> **Important Note**
>
> `--describe` shows ONLY overrides, not cluster defaults. You must separately track cluster default configurations.

**Remove configuration override:**
```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type topics --entity-name my-topic \
  --delete-config retention.ms

Updated config for topic: "my-topic".
```

**Result:** Topic reverts to cluster default retention.

---

## 5. Producing and Consuming

Two utilities allow manual message production and consumption for testing and debugging.

**In plain English:** These tools let you send and receive messages directly from the command line - like testing a walkie-talkie before the real mission.

> **Not for Production Applications**
>
> Don't wrap console tools in production applications. They're fragile and lack features. Use Java client libraries or protocol-compatible libraries in other languages instead.

### 5.1. Console Producer

The `kafka-console-producer.sh` tool writes messages to topics.

**Default behavior:**
- One message per line
- Tab separates key and value
- No tab = null key
- Raw bytes with default encoder

**Basic usage:**
```bash
kafka-console-producer.sh --bootstrap-server localhost:9092 --topic my-topic

>Message 1
>Test Message 2
>Test Message 3
>Message 4
>^D
```

> **Ending the Producer**
>
> Send EOF (End-of-File) to close: `Ctrl+D` in most terminals.

#### Producer Configuration Options

**Using a config file:**
```bash
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic my-topic \
  --producer.config /path/to/producer.properties
```

**Using command-line properties:**
```bash
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic my-topic \
  --producer-property linger.ms=100 \
  --producer-property batch.size=16384
```

**Common producer properties:**

| Property | Description |
|----------|-------------|
| `batch.size` | Number of messages per batch (async mode) |
| `timeout` | Max wait for batch before sending (async mode) |
| `compression.codec` | `none`, `gzip`, `snappy`, `zstd`, `lz4` (default: `gzip`) |
| `sync` | Send synchronously (wait for each ack) |

**Example - Synchronous compression:**
```bash
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic my-topic \
  --producer-property compression.codec=snappy \
  --producer-property sync=true
```

#### Line Reader Options

Control how input is parsed using `--property` (not `--producer-property`):

| Property | Description |
|----------|-------------|
| `parse.key` | Set to `false` for null keys (default: `true`) |
| `key.separator` | Delimiter between key and value (default: tab) |
| `ignore.error` | Continue on parse errors (default: `true`) |

**Example - Use comma as separator:**
```bash
kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic my-topic \
  --property parse.key=true \
  --property key.separator=,

>user-123,{"action":"login","timestamp":1234567890}
>user-456,{"action":"logout","timestamp":1234567900}
```

> **Property vs. Producer-Property**
>
> Confusing but important:
> - `--property`: Configures message formatter
> - `--producer-property`: Configures producer client
>
> Don't mix them up!

### 5.2. Console Consumer

The `kafka-console-consumer.sh` tool reads messages from topics.

**Default behavior:**
- Raw bytes output
- No keys displayed
- Default formatter
- Continues until `Ctrl+C`

**Basic usage:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic my-topic --from-beginning

Message 1
Test Message 2
Test Message 3
Message 4
^C
```

> **Version Warning**
>
> Use a console consumer matching your Kafka version. Old consumers can damage the cluster by incorrectly interacting with ZooKeeper or brokers.

#### Topic Selection

**Single topic:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic my-topic
```

**Multiple topics (regex):**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --whitelist 'my.*' --from-beginning

Message 1
Test Message 2
Test Message 3
Message 4
```

> **Regex Escaping**
>
> Properly escape regex patterns so the shell doesn't process them:
> ```bash
> --whitelist 'user-.*'      # Correct
> --whitelist user-.*        # May be mangled by shell
> ```

#### Common Consumer Options

| Option | Description |
|--------|-------------|
| `--from-beginning` | Start from oldest offset (default: latest) |
| `--max-messages <int>` | Exit after consuming N messages |
| `--partition <int>` | Consume only from specific partition |
| `--offset <int>` | Start from specific offset (`earliest`, `latest`, or number) |
| `--skip-message-on-error` | Continue on errors (useful for debugging) |

**Example - Consume 10 messages from partition 2:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic my-topic \
  --partition 2 \
  --max-messages 10 \
  --from-beginning
```

#### Message Formatters

**Available formatters:**

1. **DefaultMessageFormatter** (default) - Raw output
2. **LoggingMessageFormatter** - Outputs via logger at INFO level
3. **ChecksumMessageFormatter** - Prints only checksums
4. **NoOpMessageFormatter** - Consumes but outputs nothing

**Example - Checksum formatter:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic my-topic --from-beginning \
  --formatter kafka.tools.ChecksumMessageFormatter

checksum:0
checksum:0
checksum:0
checksum:0
```

#### Default Formatter Properties

Control what's displayed using `--property`:

| Property | Description |
|----------|-------------|
| `print.timestamp` | Show message timestamp |
| `print.key` | Show message key |
| `print.offset` | Show offset |
| `print.partition` | Show partition number |
| `key.separator` | Delimiter between key and value |
| `line.separator` | Delimiter between messages |
| `key.deserializer` | Class to deserialize keys |
| `value.deserializer` | Class to deserialize values |

**Example - Show all metadata:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic my-topic --from-beginning \
  --property print.timestamp=true \
  --property print.key=true \
  --property print.offset=true \
  --property print.partition=true
```

#### Consuming Consumer Offsets

**In plain English:** The `__consumer_offsets` topic stores all consumer group commit data. You can read it to see what groups are committing and how often.

**Special requirements:**
- Must use specific formatter
- Must set `exclude.internal.topics=false`

**Example:**
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic __consumer_offsets --from-beginning --max-messages 1 \
  --formatter "kafka.coordinator.group.GroupMetadataManager\$OffsetsMessageFormatter" \
  --consumer-property exclude.internal.topics=false

[my-group-name,my-topic,0]::[OffsetMetadata[1,NO_METADATA] CommitTime 1623034799990 ExpirationTime 1623639599990]
Processed a total of 1 messages
```

---

## 6. Partition Management

Advanced tools for managing partition leadership and replica assignments.

### 6.1. Preferred Replica Election

**In plain English:** Partition leadership can become unbalanced after broker restarts. Preferred replica election redistributes leadership back to the "preferred" (first) replica in each partition's replica list.

#### Understanding the Problem

```
Initial state (balanced):
Partition 0: Leader=Broker1, Follower=Broker2
Partition 1: Leader=Broker2, Follower=Broker1

Broker1 restarts:
Partition 0: Leader=Broker2, Follower=Broker1  ← Leadership moved
Partition 1: Leader=Broker2, Follower=Broker1

Result: Broker2 handles all traffic (unbalanced!)
```

**Solution:** Preferred replica election moves leadership back to Broker1 for Partition 0.

> **Automatic Balancing**
>
> Enable automatic leader rebalancing in broker configs:
> ```properties
> auto.leader.rebalance.enable=true
> ```
>
> Or use Cruise Control for smarter rebalancing.

**Manual election for all topics:**
```bash
kafka-leader-election.sh --bootstrap-server localhost:9092 \
  --election-type PREFERRED --all-topic-partitions
```

**Manual election for specific partition:**
```bash
kafka-leader-election.sh --bootstrap-server localhost:9092 \
  --election-type PREFERRED \
  --topic my-topic --partition 1
```

**Manual election from JSON file:**

Create `partitions.json`:
```json
{
  "partitions": [
    {
      "partition": 1,
      "topic": "my-topic"
    },
    {
      "partition": 2,
      "topic": "foo"
    }
  ]
}
```

Execute election:
```bash
kafka-leader-election.sh --bootstrap-server localhost:9092 \
  --election-type PREFERRED --path-to-json-file partitions.json
```

### 6.2. Reassigning Partitions

**In plain English:** Manually move partitions between brokers to balance load, add new brokers, or remove old ones.

**Common use cases:**
- Uneven load across brokers
- Broker taken offline (partition under-replicated)
- New broker added (move partitions to it)
- Adjust replication factor

#### The Process

```
Reassignment Process
────────────────────
Step 1: Generate proposal (what should move)
Step 2: Review and save proposal
Step 3: Execute moves
Step 4: Verify completion
```

#### Example Scenario

**Setup:** 4-broker cluster expanded to 6 brokers. Move topics `foo1` and `foo2` to brokers 5 and 6.

**Step 1: Create topics JSON**

Create `topics.json`:
```json
{
  "topics": [
    {
      "topic": "foo1"
    },
    {
      "topic": "foo2"
    }
  ],
  "version": 1
}
```

**Step 2: Generate proposal**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --topics-to-move-json-file topics.json \
  --broker-list 5,6 --generate

# Output shows current assignment:
{"version":1,
 "partitions":[{"topic":"foo1","partition":2,"replicas":[1,2]},
               {"topic":"foo1","partition":0,"replicas":[3,4]},
               ...]}

# And proposed reassignment:
{"version":1,
 "partitions":[{"topic":"foo1","partition":2,"replicas":[5,6]},
               {"topic":"foo1","partition":0,"replicas":[5,6]},
               ...]}
```

**Step 3: Save both outputs**
- Save current state to `revert-reassignment.json` (for rollback)
- Save proposed state to `expand-cluster-reassignment.json` (for execution)

**Step 4: Execute reassignment**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file expand-cluster-reassignment.json \
  --execute

Current partition replica assignment
...
Successfully started reassignment of partitions
...
```

**Behind the scenes:**
```
Reassignment Execution
──────────────────────
1. Add new replicas (temporarily increase RF)
2. New replicas copy data from leader
3. Wait for new replicas to catch up
4. Remove old replicas (back to original RF)
```

> **Performance Impact**
>
> Reassignments copy data across the network, causing:
> - Network saturation
> - Disk I/O spikes
> - Page cache disruption
> - Increased latency
>
> Use throttling to mitigate impact.

**Step 5: Verify completion**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file expand-cluster-reassignment.json \
  --verify

Status of partition reassignment:
Reassignment of partition [foo1,0] completed successfully
Reassignment of partition [foo1,1] is in progress
Reassignment of partition [foo1,2] is in progress
Reassignment of partition [foo2,0] completed successfully
...
```

#### Advanced Options

**Throttle reassignment:**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file expand-cluster-reassignment.json \
  --execute \
  --throttle 50000000  # 50 MB/sec
```

**Add to existing reassignment:**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file new-moves.json \
  --execute \
  --additional
```

**Disable rack awareness:**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file reassignment.json \
  --execute \
  --disable-rack-aware
```

> **Optimization: Remove Leadership First**
>
> When removing many partitions from a broker:
> 1. Restart the broker (leadership moves to other brokers)
> 2. Start reassignment
> 3. Replication traffic distributes across many brokers (faster)
>
> **Caution:** Disable auto leader rebalancing temporarily to prevent leadership returning.

**Cancel in-progress reassignment:**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file reassignment.json \
  --cancel
```

> **Cancellation Behavior**
>
> `--cancel` attempts to restore the original replica set. However:
> - Replicas may be on dead/overloaded brokers
> - Replica order may differ from original
> - Use cautiously

### 6.3. Changing Replication Factor

**In plain English:** Increase or decrease the number of replicas for fault tolerance or cost savings.

**Common scenarios:**
- Cluster default RF changed (existing topics unchanged)
- Increase redundancy as cluster grows
- Decrease RF for cost savings on test data

**Example - Increase topic "foo1" from RF=2 to RF=3:**

Create `increase-foo1-RF.json`:
```json
{
  "version":1,
  "partitions":[
    {"topic":"foo1","partition":1,"replicas":[5,6,4]},
    {"topic":"foo1","partition":2,"replicas":[5,6,4]},
    {"topic":"foo1","partition":3,"replicas":[5,6,4]}
  ]
}
```

**Execute:**
```bash
kafka-reassign-partitions.sh --bootstrap-server localhost:9092 \
  --reassignment-json-file increase-foo1-RF.json \
  --execute
```

**Verify:**
```bash
kafka-topics.sh --bootstrap-server localhost:9092 --topic foo1 --describe

Topic:foo1	PartitionCount:3	ReplicationFactor:3	Configs:
  Topic: foo1	Partition: 0	Leader: 5	Replicas: 5,6,4	Isr: 5,6,4
  Topic: foo1	Partition: 1	Leader: 5	Replicas: 5,6,4	Isr: 5,6,4
  Topic: foo1	Partition: 2	Leader: 5	Replicas: 5,6,4	Isr: 5,6,4
```

---

## 7. Advanced Operations

### 7.1. Dumping Log Segments

**In plain English:** Read the raw log files on disk to inspect individual messages - useful for debugging corrupted messages or verifying data.

**Use cases:**
- Investigate "poison pill" messages
- Verify message contents
- Diagnose corruption issues

**Log segment location:**
```
/tmp/kafka-logs/<topic-name>-<partition>/<segment-file>.log
```

**Example - Dump metadata without message contents:**
```bash
kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000000000000000000.log

Dumping /tmp/kafka-logs/my-topic-0/00000000000000000000.log
Starting offset: 0
baseOffset: 0 lastOffset: 0 count: 1 baseSequence: -1 lastSequence: -1
  producerId: -1 producerEpoch: -1 partitionLeaderEpoch: 0
  isTransactional: false isControl: false position: 0
  CreateTime: 1623034799990 size: 77 magic: 2
  compresscodec: NONE crc: 1773642166 isvalid: true
baseOffset: 1 lastOffset: 1 count: 1 baseSequence: -1 lastSequence: -1
  producerId: -1 producerEpoch: -1 partitionLeaderEpoch: 0
  isTransactional: false isControl: false position: 77
  CreateTime: 1623034803631 size: 82 magic: 2
  compresscodec: NONE crc: 1638234280 isvalid: true
...
```

**Example - Dump with message payloads:**
```bash
kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000000000000000000.log \
  --print-data-log

...
| offset: 0 CreateTime: 1623034799990 keysize: -1 valuesize: 9
    sequence: -1 headerKeys: [] payload: Message 1
| offset: 1 CreateTime: 1623034803631 keysize: -1 valuesize: 14
    sequence: -1 headerKeys: [] payload: Test Message 2
...
```

**Validate index files:**
```bash
# Quick sanity check
kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000000000000000000.index \
  --index-sanity-check

# Verify index without printing entries
kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000000000000000000.index \
  --verify-index-only
```

### 7.2. Replica Verification

**In plain English:** Verify that all replicas for a partition contain the same data - like checking that all backup drives have identical copies.

> **Performance Warning**
>
> This tool reads ALL messages from ALL replicas from the oldest offset. It generates significant cluster load. Use with caution on production systems.

**Example - Verify topics starting with "my":**
```bash
kafka-replica-verification.sh \
  --broker-list kafka.host1.domain.com:9092,kafka.host2.domain.com:9092 \
  --topic-white-list 'my.*'

2021-06-07 03:28:21,829: verification process is started.
2021-06-07 03:28:51,949: max lag is 0 for partition my-topic-0 at offset 4 among 1 partitions
2021-06-07 03:29:22,039: max lag is 0 for partition my-topic-0 at offset 4 among 1 partitions
...
```

**Understanding output:**
- `max lag is 0` - All replicas are identical
- `max lag is N` - Replicas differ by N messages (problem!)

### 7.3. Other Tools

**kafka-acls.sh**
- Manage access control lists
- Set up allow/deny rules
- Configure user permissions
- Topic and cluster-level restrictions

**kafka-mirror-maker.sh**
- Lightweight data mirroring
- Replicate between clusters
- See Chapter 10 for detailed replication strategies

**Testing tools:**
- `kafka-broker-api-versions.sh` - Check API version compatibility
- `kafka-producer-perf-test.sh` - Producer performance testing
- `kafka-consumer-perf-test.sh` - Consumer performance testing
- `trogdor.sh` - Comprehensive test framework for stress testing

---

## 8. Unsafe Operations

> **Danger: Dragons Ahead**
>
> These operations involve directly manipulating ZooKeeper metadata. They can corrupt your cluster if executed incorrectly. Use ONLY in extreme emergencies with full understanding of the risks.

### 8.1. Moving the Controller

**In plain English:** Every cluster has one broker acting as controller (manages metadata, coordinates operations). Sometimes you need to forcibly move it to another broker.

**When to use:**
- Controller is running but non-functional
- Controller suffered an exception but didn't shut down
- Troubleshooting cluster issues

**How it works:**
```
Normal Election              Force Move
──────────────               ──────────
Controller stops       →     Delete /admin/controller znode
Znode removed          →     Current controller resigns
Other brokers see it   →     Cluster elects new controller randomly
First to update wins   →     (Cannot specify which broker)
```

**Procedure:**
1. Connect to ZooKeeper
2. Delete `/admin/controller` znode
3. Cluster automatically elects new controller

> **No Targeting**
>
> You CANNOT choose which broker becomes controller. The cluster randomly selects one.

### 8.2. Removing Stuck Deletions

**In plain English:** Topic deletion can get stuck if deletion is disabled or brokers go offline during deletion.

**Scenarios causing stuck deletions:**
- Deletion requested on cluster with `delete.topic.enable=false`
- Large topic deletion started, then brokers go offline
- Deletion request cached in controller

**Procedure:**
```
1. Delete /admin/delete_topic/<topic> znode (not the parent!)
2. If controller has cached request, also move controller
   (Delete /admin/controller znode)
3. Verify topic deletion removed from pending
```

> **Timing Matters**
>
> Delete the controller znode immediately after removing the topic deletion znode to prevent cached requests from re-queueing deletion.

### 8.3. Manual Topic Deletion

**In plain English:** Manually delete a topic when automated deletion is disabled or broken. Requires full cluster shutdown.

> **Critical: Shutdown Required**
>
> ALL brokers MUST be offline before manually deleting topics. Modifying ZooKeeper metadata while the cluster is online will corrupt the cluster.

**Procedure:**

**Step 1: Shutdown cluster**
```bash
# Stop ALL brokers
systemctl stop kafka
```

**Step 2: Delete ZooKeeper metadata**
```bash
# Connect to ZooKeeper
zkCli.sh -server localhost:2181

# Delete topic (delete children first)
deleteall /brokers/topics/<topic>
```

**Step 3: Delete log directories**
```bash
# On each broker, delete partition directories
rm -rf /tmp/kafka-logs/<topic>-*
```

**Step 4: Restart cluster**
```bash
# Start ALL brokers
systemctl start kafka
```

---

## 9. Summary

**What we learned:**

**Topic Management:**
- Create topics with proper partitions and replication factor
- List, describe, and filter topics for monitoring
- Add partitions to scale (but never reduce)
- Delete topics safely with proper validation

**Consumer Groups:**
- List and describe groups to monitor lag
- Export and import offsets for recovery or repositioning
- Delete groups to reset consumer state

**Dynamic Configurations:**
- Override topic, broker, client, and user settings without restarts
- Set retention, compression, quotas, and more
- View and remove overrides to revert to defaults

**Testing Tools:**
- Use console producer/consumer for manual message handling
- Configure formatters, serializers, and properties
- Consume internal topics for debugging

**Partition Management:**
- Run preferred replica elections to rebalance leadership
- Reassign partitions to new brokers or adjust replication factor
- Throttle moves to limit performance impact
- Cancel in-progress reassignments if needed

**Advanced Operations:**
- Dump log segments to inspect messages on disk
- Verify replicas are identical across the cluster
- Use specialized tools for ACLs, mirroring, and testing

**Unsafe Operations:**
- Move controller by deleting ZooKeeper znode
- Remove stuck topic deletions
- Manually delete topics (cluster offline only)

> **Scaling Up**
>
> As clusters grow, manual CLI operations become difficult. Engage with the open source community and use automation tools like Cruise Control to manage operations at scale.

**Next:** Chapter 13 covers monitoring - because you can't manage what you can't measure. Learn to monitor broker health, cluster operations, and client performance.

---

**Previous:** [Chapter 11: Securing Kafka](./chapter11.md) | **Next:** [Chapter 13: Monitoring Kafka](./chapter13.md)
