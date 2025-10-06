# 4. Kafka Consumers: Reading Data from Kafka

> **In plain English:** A Kafka consumer is like a newspaper subscriber - it reads messages from specific topics, keeps track of what it has read, and can go back to re-read old messages if needed.
>
> **In technical terms:** A Kafka consumer is a client application that subscribes to topics and processes the stream of records stored in Kafka partitions, managing offsets to track reading progress.
>
> **Why it matters:** Consumers are how you extract value from data in Kafka. Understanding how they work - especially consumer groups, offset management, and rebalancing - is critical for building reliable, scalable data processing applications.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Consumer Concepts](#2-consumer-concepts)
   - 2.1. [Consumers and Consumer Groups](#21-consumers-and-consumer-groups)
   - 2.2. [Partition Rebalancing](#22-partition-rebalancing)
   - 2.3. [Static Group Membership](#23-static-group-membership)
3. [Creating a Consumer](#3-creating-a-consumer)
   - 3.1. [Configuration](#31-configuration)
   - 3.2. [Subscribing to Topics](#32-subscribing-to-topics)
   - 3.3. [The Poll Loop](#33-the-poll-loop)
4. [Important Configurations](#4-important-configurations)
   - 4.1. [Fetch Configurations](#41-fetch-configurations)
   - 4.2. [Session and Heartbeat](#42-session-and-heartbeat)
   - 4.3. [Offset Management](#43-offset-management)
   - 4.4. [Partition Assignment](#44-partition-assignment)
5. [Commits and Offsets](#5-commits-and-offsets)
   - 5.1. [Automatic Commits](#51-automatic-commits)
   - 5.2. [Manual Synchronous Commits](#52-manual-synchronous-commits)
   - 5.3. [Manual Asynchronous Commits](#53-manual-asynchronous-commits)
   - 5.4. [Committing Specific Offsets](#54-committing-specific-offsets)
6. [Rebalance Listeners](#6-rebalance-listeners)
7. [Consuming Specific Offsets](#7-consuming-specific-offsets)
8. [Exiting Cleanly](#8-exiting-cleanly)
9. [Deserializers](#9-deserializers)
   - 9.1. [Custom Deserializers](#91-custom-deserializers)
   - 9.2. [Avro Deserialization](#92-avro-deserialization)
10. [Standalone Consumer](#10-standalone-consumer)
11. [Summary](#11-summary)

---

## 1. Introduction

Reading data from Kafka is different from reading from traditional message queues. Kafka consumers have unique characteristics that make them powerful but require understanding.

**In plain English:** Unlike a traditional queue where messages are deleted after being read once, Kafka keeps all messages for a configured time, and consumers track their own reading position. This allows multiple consumers to read the same data independently and even go back to re-read old data.

> **💡 Insight**
>
> The ability to replay data is one of Kafka's superpowers. If a consumer has a bug that causes incorrect processing, you can fix the bug, reset the consumer's position to an earlier point, and reprocess the data correctly. Try doing that with a traditional message queue!

---

## 2. Consumer Concepts

### 2.1. Consumers and Consumer Groups

**The scaling problem:**

```
Problem: Topic receives 1 million messages/sec
Single consumer processes 100,000 messages/sec
└─> Consumer falls further behind every second
```

**The solution: Consumer Groups**

**In plain English:** A consumer group is like a team working together - they split the work (partitions) among themselves so everyone processes a different subset.

**Visual progression:**

```
1 Consumer, 4 Partitions:
Topic T1
├─ Partition 0 ──┐
├─ Partition 1 ──┼──> Consumer C1 (Group G1)
├─ Partition 2 ──┤
└─ Partition 3 ──┘

2 Consumers, 4 Partitions:
Topic T1
├─ Partition 0 ──┬──> Consumer C1 (Group G1)
├─ Partition 1 ──┘
├─ Partition 2 ──┬──> Consumer C2 (Group G1)
└─ Partition 3 ──┘

4 Consumers, 4 Partitions (ideal balance):
Topic T1
├─ Partition 0 ──> Consumer C1 (Group G1)
├─ Partition 1 ──> Consumer C2 (Group G1)
├─ Partition 2 ──> Consumer C3 (Group G1)
└─ Partition 3 ──> Consumer C4 (Group G1)

5 Consumers, 4 Partitions (one idle):
Topic T1
├─ Partition 0 ──> Consumer C1 (Group G1)
├─ Partition 1 ──> Consumer C2 (Group G1)
├─ Partition 2 ──> Consumer C3 (Group G1)
├─ Partition 3 ──> Consumer C4 (Group G1)
└─                 Consumer C5 (IDLE - no partitions)
```

**Multiple independent consumer groups:**

```
Group G1:                    Group G2:
├─ Consumer C1 ──┐           ├─ Consumer X ──┐
└─ Consumer C2 ──┼─> Topic T1 ┼─> Consumer Y ──┘
                              └─ Consumer Z

Both groups receive ALL messages
Each group tracks its own offsets independently
```

**Key rules:**

1. One partition → One consumer per group (at any time)
2. One consumer can handle multiple partitions
3. More consumers than partitions = some consumers idle
4. Different consumer groups = independent processing

> **💡 Insight**
>
> Consumer groups enable both horizontal scalability (add more consumers to process faster) and multi-tenancy (multiple applications independently consume the same data). This is a fundamental difference from traditional queues.

### 2.2. Partition Rebalancing

**When rebalances happen:**
- Consumer joins the group
- Consumer leaves the group (gracefully or crashes)
- Consumer is considered dead (stopped sending heartbeats)
- Topic partitions added

**Two types of rebalancing:**

#### Eager Rebalance (Stop-the-World)

```
Phase 1: Stop consuming
All consumers:
├─ Consumer C1: Revokes partitions 0,1 → STOPPED
├─ Consumer C2: Revokes partitions 2,3 → STOPPED
└─ Consumer C3: Revokes partitions 4,5 → STOPPED

[Gap: No messages consumed]

Phase 2: Rejoin and resume
├─ Consumer C1: Assigned partitions 0,3 → CONSUMING
├─ Consumer C2: Assigned partitions 1,4 → CONSUMING
└─ Consumer C3: Assigned partitions 2,5 → CONSUMING
```

**Impact:**
- Complete unavailability window
- Duration depends on group size
- All partitions paused

#### Cooperative Rebalance (Incremental)

```
Phase 1: Partial revocation
├─ Consumer C1: Keeps 0,1 → CONSUMING
├─ Consumer C2: Keeps 2, Revokes 3 → MOSTLY CONSUMING
└─ Consumer C3: Keeps 4,5 → CONSUMING

Phase 2: Reassignment
├─ Consumer C1: Still 0,1 → CONSUMING
├─ Consumer C2: Still 2, Gets 3 → CONSUMING
└─ Consumer C3: Still 4,5 → CONSUMING
```

**Impact:**
- Minimal unavailability (only reassigned partitions)
- Incremental, may take multiple iterations
- Most partitions never stop

> **💡 Insight**
>
> Cooperative rebalancing is like reorganizing a factory floor without shutting down the entire factory - you move one assembly line at a time while others keep working. Eager rebalancing is like shutting everything down, reorganizing, then starting back up.

**Heartbeats and Group Coordination:**

```
Consumer ──[heartbeat]──> Group Coordinator (Kafka broker)
        <─[assignment]──

Every few seconds:
├─ Consumer sends heartbeat (via background thread)
├─ Coordinator marks consumer as alive
└─ If heartbeat stops → Assume consumer dead → Rebalance
```

**Partition Assignment Process:**

```
1. Consumer joins group → Sends JoinGroup request
2. First to join = Group Leader
3. Leader receives list of all consumers
4. Leader runs PartitionAssignor
5. Leader sends assignments to Coordinator
6. Coordinator sends each consumer its assignment
```

### 2.3. Static Group Membership

**Default behavior (dynamic membership):**

```
Consumer starts → Assigned partitions
Consumer stops → Immediately triggers rebalance
Consumer restarts → Gets different partitions (maybe)
```

**Static membership (`group.instance.id` set):**

```
Consumer starts → Assigned partitions
Consumer stops → Remains member (partitions stay assigned)
Consumer restarts → Gets same partitions (no rebalance!)
```

**When to use:**

```
Use case: Consumer maintains large local cache/state
├─ Building cache takes 10 minutes
├─ Consumer restarts occasionally (deployments, crashes)
└─> Static membership avoids rebuilding cache every restart

Trade-off:
+ No rebalance on restart
+ Cache/state preserved
- Partitions unavailable until consumer returns
- Higher lag if consumer down for a while
```

**Configuration:**

```java
props.put("group.instance.id", "consumer-1"); // Unique static ID
props.put("session.timeout.ms", "300000"); // 5 minutes (high to avoid false alarms)
```

---

## 3. Creating a Consumer

### 3.1. Configuration

**Minimal consumer setup:**

```java
Properties props = new Properties();
props.put("bootstrap.servers", "broker1:9092,broker2:9092");
props.put("group.id", "CountryCounter");
props.put("key.deserializer",
    "org.apache.kafka.common.serialization.StringDeserializer");
props.put("value.deserializer",
    "org.apache.kafka.common.serialization.StringDeserializer");

KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
```

**Four key properties:**

1. **bootstrap.servers**: Initial connection points (same as producer)
2. **group.id**: Consumer group name (strongly recommended)
3. **key.deserializer**: Converts bytes to key objects
4. **value.deserializer**: Converts bytes to value objects

**In plain English:** Deserializers are the opposite of serializers - they translate bytes stored in Kafka back into Java objects your application can use.

### 3.2. Subscribing to Topics

**Subscribe to specific topics:**

```java
consumer.subscribe(Collections.singletonList("customerCountries"));
```

**Subscribe using pattern (regex):**

```java
consumer.subscribe(Pattern.compile("test.*")); // All topics starting with "test"
```

**When pattern subscription is useful:**
- Replicate all topics matching pattern to another system
- Stream processing across multiple related topics
- Dynamic topic creation (new topics automatically included)

**Warning for large clusters:**

```
Cluster with 30,000+ partitions:
├─ Client requests full topic list from broker
├─ Client filters locally using regex
├─ Repeats every few seconds
└─> High broker/client/network overhead

Recommendation: Use explicit topic list when possible
```

### 3.3. The Poll Loop

**The heart of a consumer:**

```java
Duration timeout = Duration.ofMillis(100);

while (true) { // Infinite loop is normal!
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %d, offset = %d, " +
                        "customer = %s, country = %s%n",
        record.topic(), record.partition(), record.offset(),
        record.key(), record.value());

        // Process the record
        int count = custCountryMap.getOrDefault(record.value(), 0);
        custCountryMap.put(record.value(), count + 1);
    }
}
```

**What `poll()` does:**

```
First poll():
├─ Find GroupCoordinator
├─ Join consumer group
├─ Receive partition assignment
└─ Fetch records

Subsequent polls:
├─ Send heartbeats (via background thread)
├─ Handle rebalances (if needed)
├─ Fetch more records
└─ Return records to process
```

**Critical rules:**

1. Must call `poll()` regularly (within `max.poll.interval.ms`)
2. Don't do unpredictable blocking inside the loop
3. Process all records before next `poll()`
4. One consumer per thread (consumers not thread-safe)

> **💡 Insight**
>
> The poll loop is like a shark - it must keep moving or it dies. If you don't call poll() frequently enough, the group coordinator thinks your consumer died and triggers a rebalance. Keep the loop moving!

**Thread safety warning:**

```
WRONG (multiple threads, one consumer):
Thread 1: consumer.poll()
Thread 2: consumer.poll()
└─> ConcurrentModificationException

CORRECT (one consumer per thread):
Thread 1: consumer1.poll()
Thread 2: consumer2.poll()
```

---

## 4. Important Configurations

### 4.1. Fetch Configurations

#### fetch.min.bytes

**Purpose:** Minimum bytes to fetch before responding

```java
props.put("fetch.min.bytes", "1024"); // Wait for at least 1KB
```

**How it works:**

```
fetch.min.bytes = 1 (default):
Consumer requests data → Broker returns immediately (even 1 byte)
+ Lowest latency
- More requests (higher overhead)

fetch.min.bytes = 1024:
Consumer requests data → Broker waits until 1KB available
+ Fewer requests (lower overhead)
- Slightly higher latency
```

#### fetch.max.wait.ms

**Purpose:** Maximum time to wait when `fetch.min.bytes` not met

```java
props.put("fetch.max.wait.ms", "500"); // Default
```

**Interaction:**

```
fetch.min.bytes = 1MB
fetch.max.wait.ms = 100ms

Broker behavior:
├─ Wait for 1MB of data
├─ OR wait for 100ms
└─> Whichever happens first
```

#### fetch.max.bytes

**Purpose:** Maximum bytes per fetch request

```java
props.put("fetch.max.bytes", "52428800"); // 50 MB (default)
```

**Important exception:**

```
If first batch > fetch.max.bytes:
└─> Send it anyway (ensures progress)
```

#### max.poll.records

**Purpose:** Maximum records per `poll()` call

```java
props.put("max.poll.records", "500"); // Default
```

**Use case:**

```
Processing time per record: 100ms
max.poll.records = 500

Time to process one poll batch:
500 records × 100ms = 50 seconds

If max.poll.interval.ms = 300000 (5 min):
└─> Safe (50s < 5min)

If max.poll.interval.ms = 30000 (30s):
└─> DANGER! Will be kicked from group
```

### 4.2. Session and Heartbeat

#### session.timeout.ms

**Purpose:** How long consumer can go without heartbeat before considered dead

```java
props.put("session.timeout.ms", "10000"); // 10 seconds (default)
```

#### heartbeat.interval.ms

**Purpose:** How often to send heartbeats

```java
props.put("heartbeat.interval.ms", "3000"); // 3 seconds (default)
```

**Rule of thumb:**

```
heartbeat.interval.ms = session.timeout.ms / 3

Example:
session.timeout.ms = 10000
heartbeat.interval.ms = 3000

Timeline:
0s:  Heartbeat sent ✓
3s:  Heartbeat sent ✓
6s:  Heartbeat sent ✓
9s:  Heartbeat sent ✓
10s: If no heartbeat → Consumer considered dead
```

**Trade-offs:**

```
Short session timeout (e.g., 6s):
+ Faster failure detection
+ Quicker recovery
- Risk of false alarms (network hiccup = rebalance)

Long session timeout (e.g., 45s):
+ More tolerant of temporary issues
- Slower to detect real failures
- Longer delay before recovering
```

#### max.poll.interval.ms

**Purpose:** Maximum time between `poll()` calls

```java
props.put("max.poll.interval.ms", "300000"); // 5 minutes (default)
```

**Why separate from heartbeats:**

```
Background thread sends heartbeats ← Shows consumer process alive
Main thread calls poll()          ← Shows consumer making progress

Scenario: Deadlocked main thread
├─ Background thread: Still sending heartbeats ✓
├─ Main thread: Stuck, not calling poll() ✗
└─> max.poll.interval.ms detects this!
```

### 4.3. Offset Management

#### auto.offset.reset

**Purpose:** What to do when no committed offset exists

```java
props.put("auto.offset.reset", "latest"); // Default
```

**Options:**

```
"earliest":
└─> Start from beginning of partition

"latest":
└─> Start from end of partition (only new messages)

"none":
└─> Throw exception
```

**Common scenarios:**

```
New consumer group:
├─ No committed offsets exist
├─> auto.offset.reset decides starting point

Consumer down for 30 days:
├─ Committed offset aged out (retention expired)
├─> auto.offset.reset decides starting point
```

#### enable.auto.commit

**Purpose:** Whether consumer automatically commits offsets

```java
props.put("enable.auto.commit", "true"); // Default
```

**Will discuss in detail in Commits and Offsets section.**

### 4.4. Partition Assignment

#### partition.assignment.strategy

**Purpose:** How to distribute partitions among consumers

**Range (default):**

```
Topic T1: 3 partitions, Topic T2: 3 partitions
Consumers: C1, C2

Assignment:
C1: T1-P0, T1-P1, T2-P0, T2-P1
C2: T1-P2, T2-P2

Result: Imbalanced (C1 has 4, C2 has 2)
```

**RoundRobin:**

```
Topic T1: 3 partitions, Topic T2: 3 partitions
Consumers: C1, C2

Assignment:
C1: T1-P0, T1-P2, T2-P1
C2: T1-P1, T2-P0, T2-P2

Result: Balanced (C1 has 3, C2 has 3)
```

**Sticky:**

```
Like RoundRobin but minimizes partition movement during rebalance

Initial: C1:[P0,P1,P2], C2:[P3,P4,P5]
C3 joins: C1:[P0,P1], C2:[P3,P4], C3:[P2,P5]
          Only P2 and P5 moved!
```

**CooperativeSticky:**

```
Same as Sticky + uses cooperative rebalancing
├─> Best of both worlds
└─> Recommended for new applications
```

---

## 5. Commits and Offsets

**In plain English:** Committing an offset means telling Kafka "I've successfully processed all messages up to this point." This allows consumers to resume from the right place after restarts or rebalances.

### Understanding Offsets

```
Partition:  [Msg 0][Msg 1][Msg 2][Msg 3][Msg 4][Msg 5]
                              ↑
                    Last committed offset: 2
                    (Means: processed 0, 1, 2)

If consumer crashes and restarts:
└─> Resumes from offset 3
```

**The risks:**

```
Commit too early (before processing):
├─ Crash happens
├─ Restart from committed offset
└─> Messages lost (never processed)

Commit too late (after processing):
├─ Crash happens
├─> Messages reprocessed (duplicates)
```

### 5.1. Automatic Commits

**How it works:**

```java
props.put("enable.auto.commit", "true"); // Default
props.put("auto.commit.interval.ms", "5000"); // Every 5 seconds
```

**Commit timing:**

```
Timeline:
0s:    poll() → Commit last offset from previous poll
0-5s:  Process messages
5s:    poll() → Commit again
5-10s: Process messages
10s:   poll() → Commit again
```

**The duplicate window:**

```
0s:   Last commit (offset 1000)
3s:   Consumer crashes (processed up to offset 1500)
      [Rebalance]
      New consumer starts from offset 1000
      ↓
      Reprocesses 1000-1500 (duplicates!)
```

**When to use:**
- Message loss is unacceptable
- Duplicate processing is acceptable
- Simplicity is important

### 5.2. Manual Synchronous Commits

**How it works:**

```java
props.put("enable.auto.commit", "false");

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        // Process record
        System.out.printf("Processing: %s%n", record.value());
    }

    try {
        consumer.commitSync(); // Block until commit succeeds
    } catch (CommitFailedException e) {
        log.error("Commit failed", e);
    }
}
```

**Trade-off:**

```
Synchronous commit:
+ Every record processed before committing
+ Fewer duplicates on crash
- Throughput reduced (blocking)
- Latency increased (waiting for commit)
```

**Duplicate scenario:**

```
Process: 1000, 1001, 1002
Call commitSync()
[Crash before commit response arrives]
Restart: Process 1000, 1001, 1002 again (duplicates)
```

### 5.3. Manual Asynchronous Commits

**How it works:**

```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        // Process record
        System.out.printf("Processing: %s%n", record.value());
    }

    consumer.commitAsync((offsets, exception) -> {
        if (exception != null) {
            log.error("Commit failed for offsets {}", offsets, exception);
        }
    });
}
```

**Why no automatic retry:**

```
Timeline:
├─ commitAsync(offset=2000) [sent]
├─ commitAsync(offset=3000) [succeeds]
├─ Response for offset=2000 [fails]
└─> Should NOT retry offset=2000!
    (Would overwrite the newer offset=3000)
```

**Best pattern (combining both):**

```java
try {
    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);

        for (ConsumerRecord<String, String> record : records) {
            // Process record
        }

        consumer.commitAsync(); // Fast, non-blocking
    }
} finally {
    try {
        consumer.commitSync(); // Final commit on shutdown (retry until success)
    } finally {
        consumer.close();
    }
}
```

> **💡 Insight**
>
> Use commitAsync() in the normal loop for speed, but use commitSync() before closing to ensure the final offset is committed. This gives you both high throughput and reliability on shutdown.

### 5.4. Committing Specific Offsets

**Use case:** Commit more frequently than once per poll batch

```java
private Map<TopicPartition, OffsetAndMetadata> currentOffsets = new HashMap<>();
int count = 0;

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        // Process record
        System.out.printf("Processing: %s%n", record.value());

        // Track offset for this partition
        currentOffsets.put(
            new TopicPartition(record.topic(), record.partition()),
            new OffsetAndMetadata(record.offset() + 1, "metadata")); // +1!

        if (count % 1000 == 0) {
            consumer.commitAsync(currentOffsets, null);
        }
        count++;
    }
}
```

**Critical detail:**

```
record.offset() = 5000 (last processed)
Commit: 5001 (next offset to read)

Why +1? Committed offset = "next offset to consume"
```

---

## 6. Rebalance Listeners

**Purpose:** Run code when partitions are assigned or revoked

```java
private class HandleRebalance implements ConsumerRebalanceListener {

    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        // Partitions assigned to this consumer
        // Initialize resources, load state, seek to offsets
        System.out.println("Assigned partitions: " + partitions);
    }

    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        // About to lose these partitions
        // Commit offsets, save state, clean up resources
        System.out.println("Losing partitions: " + partitions);
        consumer.commitSync(currentOffsets);
    }

    public void onPartitionsLost(Collection<TopicPartition> partitions) {
        // Partitions lost without clean revocation (cooperative rebalance only)
        // Clean up carefully (new owner may already exist)
        System.out.println("Partitions lost: " + partitions);
    }
}

consumer.subscribe(topics, new HandleRebalance());
```

**When each is called:**

```
Eager rebalance:
├─ onPartitionsRevoked() [before rebalance]
└─ onPartitionsAssigned() [after rebalance]

Cooperative rebalance (normal):
├─ onPartitionsRevoked() [only for partitions being reassigned]
└─ onPartitionsAssigned() [called every rebalance, even if empty]

Cooperative rebalance (exceptional):
└─ onPartitionsLost() [partitions already have new owners]
```

---

## 7. Consuming Specific Offsets

**Seek to beginning:**

```java
consumer.seekToBeginning(consumer.assignment());
```

**Seek to end:**

```java
consumer.seekToEnd(consumer.assignment());
```

**Seek to specific time:**

```java
Long oneHourAgo = Instant.now().atZone(ZoneId.systemDefault())
    .minusHours(1).toEpochSecond();

Map<TopicPartition, Long> partitionTimestamps = consumer.assignment()
    .stream()
    .collect(Collectors.toMap(tp -> tp, tp -> oneHourAgo));

Map<TopicPartition, OffsetAndTimestamp> offsetMap =
    consumer.offsetsForTimes(partitionTimestamps);

for (Map.Entry<TopicPartition, OffsetAndTimestamp> entry : offsetMap.entrySet()) {
    consumer.seek(entry.getKey(), entry.getValue().offset());
}
```

**Use cases:**
- Reprocess data after fixing a bug
- Start processing from a specific time
- Skip corrupted data

---

## 8. Exiting Cleanly

**How to shut down:**

```java
Runtime.getRuntime().addShutdownHook(new Thread() {
    public void run() {
        System.out.println("Starting exit...");
        consumer.wakeup(); // Only safe method from another thread
        try {
            mainThread.join();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
});

try {
    while (true) {
        ConsumerRecords<String, String> records = consumer.poll(timeout);

        for (ConsumerRecord<String, String> record : records) {
            // Process record
        }

        consumer.commitSync();
    }
} catch (WakeupException e) {
    // Expected on shutdown, ignore
} finally {
    consumer.close(); // Commits offsets and leaves group
    System.out.println("Closed consumer");
}
```

**What happens:**

```
Main thread: poll() [waiting]
             ↓
Shutdown hook: consumer.wakeup()
             ↓
Main thread: WakeupException thrown → Caught → close()
             ↓
Consumer sends leave message → Triggers immediate rebalance
```

---

## 9. Deserializers

### 9.1. Custom Deserializers

**Matching the producer's Customer serializer:**

```java
public class CustomerDeserializer implements Deserializer<Customer> {

    @Override
    public Customer deserialize(String topic, byte[] data) {
        try {
            if (data == null) return null;

            if (data.length < 8)
                throw new SerializationException("Data too short");

            ByteBuffer buffer = ByteBuffer.wrap(data);
            int id = buffer.getInt();
            int nameSize = buffer.getInt();

            byte[] nameBytes = new byte[nameSize];
            buffer.get(nameBytes);
            String name = new String(nameBytes, "UTF-8");

            return new Customer(id, name);
        } catch (Exception e) {
            throw new SerializationException("Error deserializing", e);
        }
    }
}
```

**The fragility problem:**

```
Producer schema v1: [ID][Name]
Consumer expects v1: Works ✓

Producer updates to v2: [ID][Name][Email]
Consumer still expects v1: BREAKS ✗

Result: Coordinated deployment required
```

### 9.2. Avro Deserialization

**Using Avro consumer:**

```java
Properties props = new Properties();
props.put("bootstrap.servers", "broker1:9092");
props.put("group.id", "CountryCounter");
props.put("key.deserializer",
    "org.apache.kafka.common.serialization.StringDeserializer");
props.put("value.deserializer",
    "io.confluent.kafka.serializers.KafkaAvroDeserializer");
props.put("specific.avro.reader", "true");
props.put("schema.registry.url", schemaUrl);

KafkaConsumer<String, Customer> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Collections.singletonList("customerContacts"));

while (true) {
    ConsumerRecords<String, Customer> records = consumer.poll(timeout);

    for (ConsumerRecord<String, Customer> record : records) {
        System.out.println("Customer: " + record.value().getName());
    }
    consumer.commitSync();
}
```

**How it handles schema evolution:**

```
Producer writes with schema v2 (has email field)
Consumer reads with schema v1 (no email field)
├─> Avro deserializer gets v2 schema from registry
├─> Converts to v1 format (drops email field)
└─> Consumer receives compatible Customer object ✓
```

---

## 10. Standalone Consumer

**When to use:** You want to read specific partitions without group coordination

```java
List<PartitionInfo> partitionInfos = consumer.partitionsFor("topic");

List<TopicPartition> partitions = new ArrayList<>();
for (PartitionInfo partition : partitionInfos) {
    partitions.add(new TopicPartition(partition.topic(), partition.partition()));
}

consumer.assign(partitions); // Not subscribe()!

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(timeout);

    for (ConsumerRecord<String, String> record : records) {
        System.out.printf("topic = %s, partition = %d, offset = %d%n",
            record.topic(), record.partition(), record.offset());
    }
    consumer.commitSync();
}
```

**Key differences:**

```
subscribe() (with group):
├─ Automatic partition assignment
├─ Automatic rebalancing
├─ Share partitions with other consumers
└─> Cannot use with assign()

assign() (standalone):
├─ Manual partition specification
├─ No rebalancing
├─ Full control over which partitions
└─> Cannot use with subscribe()
```

**Use cases:**
- Always read ALL partitions (no parallelism needed)
- Read specific partitions only
- Simple use case, don't need group features

---

## 11. Summary

**What we learned:**

1. **Consumer Groups**: Enable horizontal scaling by distributing partitions among consumers

2. **Rebalancing**:
   - Eager: Stop-the-world (all partitions paused)
   - Cooperative: Incremental (minimal disruption)
   - Triggered by consumer join/leave/failure

3. **The Poll Loop**: Heart of the consumer, must call regularly

4. **Critical Configurations**:
   - Session timeout vs heartbeat interval
   - max.poll.interval.ms for main thread liveness
   - fetch configurations for performance
   - partition.assignment.strategy for distribution

5. **Offset Management**:
   - Automatic: Simple, small duplicate window
   - Manual sync: Blocking, fewer duplicates
   - Manual async: Fast, requires careful error handling
   - Specific offsets: Maximum control

6. **Rebalance Listeners**: Run code when partitions assigned/revoked

7. **Seeking**: Ability to reprocess data from specific points

8. **Deserialization**:
   - Custom deserializers fragile
   - Avro provides schema evolution

9. **Standalone Consumers**: Manual partition assignment without groups

**Key takeaway:** Kafka consumers are fundamentally different from traditional queue consumers. They track their own position (offsets), can reprocess data, and scale horizontally through consumer groups. Understanding offset management and rebalancing is critical for building reliable applications.

---

**Previous:** [Chapter 3: Kafka Producers](./chapter3.md) | **Next:** [Chapter 5: Managing Kafka Programmatically →](./chapter5.md)
