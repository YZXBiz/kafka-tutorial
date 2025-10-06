# 7. Reliable Data Delivery

> **In plain English:** Reliability in Kafka is like building a supply chain - it's not enough for one truck to be dependable; the entire system from factory to warehouse to delivery must work together flawlessly.
>
> **In technical terms:** Reliability is a system property involving coordinated configuration of brokers, topics, producers, and consumers to guarantee specific delivery semantics under all failure conditions.
>
> **Why it matters:** The difference between a toy system and a production system is reliability. When tracking credit card payments or medical records, "usually works" isn't good enough - you need guarantees that hold even when servers crash, networks partition, or disks fail.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Reliability Guarantees](#2-reliability-guarantees)
3. [Replication](#3-replication)
   - 3.1. [In-Sync Replicas](#31-in-sync-replicas)
   - 3.2. [Out-of-Sync Replicas](#32-out-of-sync-replicas)
4. [Broker Configuration](#4-broker-configuration)
   - 4.1. [Replication Factor](#41-replication-factor)
   - 4.2. [Unclean Leader Election](#42-unclean-leader-election)
   - 4.3. [Minimum In-Sync Replicas](#43-minimum-in-sync-replicas)
5. [Using Producers Reliably](#5-using-producers-reliably)
   - 5.1. [Send Acknowledgments](#51-send-acknowledgments)
   - 5.2. [Configuring Producer Retries](#52-configuring-producer-retries)
   - 5.3. [Additional Error Handling](#53-additional-error-handling)
6. [Using Consumers Reliably](#6-using-consumers-reliably)
   - 6.1. [Important Consumer Configurations](#61-important-consumer-configurations)
   - 6.2. [Committing Offsets](#62-committing-offsets)
   - 6.3. [Rebalances and Retries](#63-rebalances-and-retries)
7. [Validating System Reliability](#7-validating-system-reliability)
   - 7.1. [Validating Configuration](#71-validating-configuration)
   - 7.2. [Validating Applications](#72-validating-applications)
   - 7.3. [Monitoring in Production](#73-monitoring-in-production)
8. [Summary](#8-summary)

---

## 1. Introduction

**In plain English:** Think of reliability like a relay race - every runner (broker, producer, consumer) must do their part correctly, and the baton (message) must pass between them without being dropped.

Reliability is not a single Kafka feature - it's a property of the entire system. When discussing Kafka's reliability guarantees, we must consider:

- The Kafka brokers and their configuration
- The topics and their configuration
- The producer applications and how they use the API
- The consumer applications and how they use the API
- The administrators who configure and monitor everything

> **💡 Insight**
>
> Reliability is everyone's responsibility. A perfectly configured Kafka cluster can lose data if producers don't handle errors correctly. Perfect producers can't guarantee delivery if consumers commit offsets before processing messages.

**Kafka's flexibility:**
- Some use cases prioritize speed over reliability (click tracking)
- Others require utmost reliability (payment processing)
- Kafka is configurable enough to support both extremes and everything in between

---

## 2. Reliability Guarantees

**In plain English:** Guarantees are promises about system behavior under specific conditions - like a warranty that tells you exactly what's covered and what's not.

Understanding guarantees is critical. Just as ACID guarantees make relational databases trustworthy for critical applications, Kafka's guarantees allow developers to build reliable systems with confidence.

**Kafka's core guarantees:**

1. **Ordered messages within a partition**
   - Message B written after message A (same producer, same partition) will have higher offset
   - Consumers read message A before message B

2. **Committed messages survive**
   - Messages written to all in-sync replicas are "committed"
   - Committed messages won't be lost as long as one replica survives
   - Producers can wait for commit acknowledgment

3. **Only committed messages are readable**
   - Consumers only see messages that are committed
   - No "dirty reads" of uncommitted data

> **💡 Insight**
>
> These basic guarantees are building blocks. The complete reliability story depends on how brokers, producers, and consumers are configured to use these guarantees.

**The tradeoff landscape:**
```
Reliability ←→ Performance
      ↕
Availability ←→ Consistency
      ↕
Latency ←→ Throughput
      ↕
Cost ←→ Durability
```

Understanding these tradeoffs lets you make informed configuration choices.

---

## 3. Replication

**In plain English:** Replication is like having photocopies of important documents stored in different buildings - if one building burns down, you haven't lost anything.

### 3.1. In-Sync Replicas

**Quick recap from Chapter 6:**

Each partition has:
- One leader replica (handles all reads/writes)
- Multiple follower replicas (stay synchronized)
- Automatic leader election when leader fails

**A replica is in-sync if:**

1. **Active ZooKeeper session** - Heartbeat within 6 seconds (configurable)
2. **Recently fetched** - Requested messages from leader in last 10 seconds
3. **Caught up** - No lag in last 10 seconds (has latest messages)

**The fetch dance:**
```
Follower → Leader: "Send messages from offset 1000"
Leader → Follower: [Messages 1000-1100]
Leader records: "Follower is at offset 1100"

If follower stops requesting or falls behind:
├── After 10 seconds → Marked out-of-sync
└── No longer eligible for leader election
```

> **💡 Insight**
>
> The replica.lag.time.max.ms parameter (default 30s) controls this behavior. Increased from 10s to 30s in Kafka 2.5 to improve cloud environment stability, where network latency varies more.

### 3.2. Out-of-Sync Replicas

**Performance impact:**

```
All replicas in-sync:
├── Producers wait for all replicas
└── Slightly higher latency

One replica out-of-sync:
├── Producers only wait for remaining in-sync replicas
└── Better performance
└── BUT: Lower effective replication factor = higher risk
```

**Getting back in-sync:**
```
1. Reconnect to ZooKeeper
2. Resume fetching from leader
3. Catch up to latest messages
4. Automatically marked in-sync again

Usually fast (seconds) after:
- Network glitch resolved
- Garbage collection pause ends
- Broker restart completes
```

**Historical context:** In older Kafka versions, replicas frequently flipped between in-sync and out-of-sync. This indicated problems like:
- Large messages causing long GC pauses
- Insufficient memory leading to JVM pauses
- Network congestion

Modern Kafka (2.5+) with proper configuration rarely shows this behavior.

---

## 4. Broker Configuration

**In plain English:** Broker configuration is like setting the rules for a warehouse - how many backup copies to keep, what to do when workers are absent, and when to refuse new shipments.

Three key configurations affect reliability. They can be set cluster-wide (broker level) or per-topic.

### 4.1. Replication Factor

**Configuration:**
- Topic level: `replication.factor`
- Broker level: `default.replication.factor` (for auto-created topics)

**What it means:**
```
Replication factor N:
├── Can lose N-1 brokers without data loss
├── Stores N copies of the data
└── Requires N times disk space
```

**Example:**
```
Replication factor = 3
├── Topic survives 2 broker failures
├── 3 copies of every message
└── 3x storage cost
```

**Tradeoffs to consider:**

1. **Availability**
   ```
   Single replica:
   ├── Partition offline during broker restart
   └── Even brief maintenance causes downtime

   Three replicas:
   ├── Survive broker restarts
   └── Higher availability
   ```

2. **Durability**
   ```
   Single disk failure:
   ├── One replica = Total data loss
   └── Three replicas = No data loss
   ```

3. **Throughput**
   ```
   Produce at 10 MBps:
   ├── 1 replica = 0 replication traffic
   ├── 2 replicas = 10 MBps replication
   ├── 3 replicas = 20 MBps replication
   └── 5 replicas = 40 MBps replication

   Must account for this in capacity planning!
   ```

4. **Latency**
   ```
   More replicas = Higher probability of slow replica
   └── Slows down all clients using that partition
   ```

5. **Cost**
   ```
   3 replicas on storage with 3x redundancy:
   └── Expensive! Consider 2 replicas on such storage
       (Lower availability but same durability)
   ```

**Rack awareness:**
```
Without rack awareness:
└── All replicas might be on same rack
    └── Rack failure = Complete data loss

With broker.rack configuration:
└── Replicas spread across racks
    └── Rack failure = Still have replicas
```

> **💡 Insight**
>
> In cloud environments, treat availability zones as racks. Configure broker.rack with the zone name to protect against zone-level failures.

### 4.2. Unclean Leader Election

**Configuration:** `unclean.leader.election.enable` (default: `false`)

**In plain English:** Unclean leader election is like promoting someone who missed the last week of training to team lead - they might make mistakes based on outdated information.

**The scenario:**
```
Partition has 3 replicas:
1. Two followers crash (Brokers down)
2. Leader keeps accepting messages
3. Leader crashes (All replicas offline!)

Now what?
├── Out-of-sync replica available (was offline, missed messages)
└── No in-sync replica exists

Choice:
├── Wait for old leader (possibly hours)
└── OR promote out-of-sync replica (lose data)
```

**Why unclean election is dangerous:**

```
Timeline:
1. Leader has messages 0-200, followers offline
2. Leader crashes, Follower 1 (has 0-100) becomes leader
3. Producer writes NEW messages 101-200
4. Consumer reads messages 101-200

Result:
├── OLD messages 101-200 lost forever
├── NEW messages 101-200 exist
└── Inconsistency! Some consumers saw old, some saw new
```

> **💡 Insight**
>
> Setting `unclean.leader.election.enable=false` (default) prioritizes consistency over availability. Partitions stay offline until the last in-sync leader returns or admin intervention.

**When to override (temporarily):**
```
Extreme situation:
├── All in-sync replicas gone
├── Partition has been offline for hours
└── Business demands availability over consistency

Admin can:
1. Set unclean.leader.election.enable=true
2. Restart cluster to elect out-of-sync replica
3. Accept the data loss
4. Set it back to false after recovery
```

### 4.3. Minimum In-Sync Replicas

**Configuration:**
- Topic level: `min.insync.replicas`
- Broker level: `min.insync.replicas`

**In plain English:** This is like requiring at least two people to approve a transaction - if only one person is available, transactions are blocked until more approvers return.

**The problem it solves:**

```
Topic with 3 replicas:
├── Two replicas crash
└── Only leader remains (still "in-sync")

With acks=all:
├── Leader alone is "all in-sync replicas"
├── Producer gets acknowledgment
└── If leader crashes, data is LOST
    (No other copy existed)
```

**How min.insync.replicas helps:**

```
Set min.insync.replicas=2:

All 3 replicas in-sync:
└── Everything works normally

2 replicas in-sync:
└── Still works (meets minimum)

Only 1 replica in-sync:
├── Broker rejects produce requests
├── Throws NotEnoughReplicasException
└── Partition becomes read-only
```

**Recovery:**
```
Read-only state:
├── Consumers can still read existing data
├── Producers receive errors

To recover:
├── Restart one of the unavailable brokers
├── Wait for replica to catch up
└── Automatically exits read-only state
```

> **💡 Insight**
>
> Common pattern: Replication factor 3, min.insync.replicas 2. This tolerates one broker failure while ensuring data is always on at least two brokers.

---

## 5. Using Producers Reliably

**In plain English:** Even perfectly configured brokers can lose data if producers don't handle errors correctly - like having a reliable postal service but writing the wrong address on envelopes.

### 5.1. Send Acknowledgments

**Configuration:** `acks` (acknowledgment mode)

**Three options:**

**acks=0 (No acknowledgment)**
```
Producer → Network → Broker
             ↓
      "Consider it sent!"

Errors detected:
├── Serialization failure
├── Network card failure
└── Nothing else

Errors NOT detected:
├── Partition offline
├── Leader election in progress
├── Entire cluster down
└── Message lost but producer doesn't know
```

Use when: Metrics, logs, or data where some loss is acceptable

**acks=1 (Leader acknowledgment)**
```
Producer → Leader → Followers (async)
              ↓
        "I got it!"

Timeline:
1. Leader receives and writes to disk
2. Leader sends ack to producer
3. Leader crashes before replicating
4. New leader doesn't have the message
└── Data lost but producer thinks it succeeded
```

Use when: Moderate reliability needed, can tolerate occasional loss

**acks=all (All in-sync replicas)**
```
Producer → Leader → Followers
              ↓       ↓
        Waits for all in-sync replicas
              ↓
        "All replicas have it!"

Combined with min.insync.replicas=2:
└── Guaranteed on at least 2 replicas before ack
    └── Most reliable option
```

Use when: Cannot afford any data loss

> **💡 Insight**
>
> acks=all doesn't necessarily mean higher latency for end-to-end delivery. Consumers must wait for replication anyway, so acks=all just makes the producer wait for what's already happening.

### 5.2. Configuring Producer Retries

**In plain English:** Retries are like automatically re-mailing a letter that bounced - smart retry logic ensures delivery without creating duplicates.

**Two error categories:**

**Retriable errors:**
```
LEADER_NOT_AVAILABLE:
├── New broker election in progress
└── Retry usually succeeds

NETWORK_ERROR:
├── Temporary network issue
└── Retry likely succeeds
```

**Non-retriable errors:**
```
INVALID_CONFIG:
├── Configuration is wrong
└── Retry will fail the same way

MESSAGE_TOO_LARGE:
├── Message exceeds broker limit
└── Retry won't help
```

**Recommended configuration:**

```
retries = MAX_INT (effectively infinite)
delivery.timeout.ms = 120000 (2 minutes)

Behavior:
├── Producer retries as many times as possible
├── Within 2-minute window
└── Gives up after timeout
```

**Idempotent producer (enable.idempotence=true):**
```
Without idempotence:
├── Retry might create duplicate
└── Both original and retry succeed
    └── Message appears twice

With idempotence:
├── Producer adds sequence number
├── Broker detects duplicate
└── Deduplicates automatically
    └── At-least-once becomes effectively exactly-once
```

> **💡 Insight**
>
> Always use enable.idempotence=true. It prevents duplicates from retries with minimal overhead. The days of choosing between reliability and duplicate-free delivery are over.

### 5.3. Additional Error Handling

**Errors requiring application logic:**

1. **Non-retriable broker errors**
   ```
   Examples:
   ├── INVALID_MESSAGE_SIZE
   ├── AUTHORIZATION_FAILED
   └── Application must decide:
       ├── Log and skip?
       ├── Alert administrator?
       └── Store in error topic?
   ```

2. **Errors before broker**
   ```
   SerializationException:
   └── Message couldn't be serialized
       └── Application bug or data corruption
   ```

3. **Retry exhaustion**
   ```
   All retries used:
   └── delivery.timeout.ms expired
       └── Critical error requiring investigation
   ```

4. **Timeout errors**
   ```
   No response within configured time:
   └── Could be network issue or overloaded broker
   ```

**Error handler patterns:**

```
Sync send error handling:
try {
    producer.send(record).get();
} catch (Exception e) {
    // Handle non-retriable errors
    if (e instanceof AuthorizationException) {
        // Alert admin - config issue
    } else if (e instanceof SerializationException) {
        // Log bad record - data issue
    } else {
        // Unexpected error - investigate
    }
}

Async send error handling:
producer.send(record, (metadata, exception) -> {
    if (exception != null) {
        // Categorize and handle error
    }
});
```

> **💡 Insight**
>
> Don't implement your own retry logic on top of the producer's built-in retries. Use the producer's retry mechanism with idempotence - it's safer and better tested.

---

## 6. Using Consumers Reliably

**In plain English:** Consumer reliability is about ensuring you process each message exactly once - like checking off items on a to-do list without skipping any or doing the same task twice.

### 6.1. Important Consumer Configurations

**Four key configurations:**

**1. group.id**
```
Same group.id:
└── Partitions split among consumers
    └── Each consumer reads subset

Different group.id:
└── Each consumer reads ALL messages
    └── Independent processing
```

**2. auto.offset.reset**
```
earliest:
├── Start from beginning if no offset exists
├── Minimizes data loss
└── May reprocess old data

latest:
├── Start from end if no offset exists
├── Minimizes duplicate processing
└── May miss messages
```

**3. enable.auto.commit**
```
true (automatic):
├── Offsets committed on schedule
├── Less code to write
└── Risk: Commit messages not fully processed

false (manual):
├── Application controls commit timing
├── More code and complexity
└── Precise control over processing guarantees
```

**4. auto.commit.interval.ms**
```
Frequent commits (e.g., 1 second):
├── More overhead
└── Fewer duplicates on failure

Infrequent commits (e.g., 5 seconds):
├── Less overhead
└── More duplicates on failure
```

> **💡 Insight**
>
> Minimize rebalances to maintain reliability. Frequent rebalances cause processing delays and increase duplicate risk. Tune session timeouts and max.poll.interval.ms carefully.

### 6.2. Committing Offsets

**In plain English:** Committing offsets is like bookmarking your place in a book - you need to mark the right page at the right time so you can resume reading without missing or rereading chapters.

**Critical rule: Only commit after processing**

```
Wrong:
1. Poll messages
2. Commit offset
3. Process messages  ← If crash here, messages lost!

Right:
1. Poll messages
2. Process messages
3. Commit offset  ← If crash here, reprocess (safe)
```

**Commit frequency tradeoff:**

```
Commit every message:
├── Minimal duplicates on crash
├── High overhead
└── Only for low-throughput topics

Commit every batch:
├── Balanced overhead
└── Moderate duplicates on crash

Commit every N batches:
├── Low overhead
├── Higher duplicates on crash
└── Best for high-throughput
```

**Common commit patterns:**

**Pattern 1: Auto-commit in poll loop**
```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        process(record);  // Must complete before next poll
    }
    // Auto-commit happens here
}
```

**Pattern 2: Manual commit after processing**
```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        process(record);
    }
    consumer.commitSync();  // Explicit commit
}
```

**Pattern 3: Commit specific offsets**
```java
Map<TopicPartition, OffsetAndMetadata> offsets = new HashMap<>();
for (ConsumerRecord<String, String> record : records) {
    process(record);
    offsets.put(
        new TopicPartition(record.topic(), record.partition()),
        new OffsetAndMetadata(record.offset() + 1)  // +1 for next offset
    );
}
consumer.commitSync(offsets);
```

> **💡 Insight**
>
> The offset you commit is the NEXT offset to read, not the last one processed. If you processed offset 100, commit 101. Getting this wrong is a common source of message loss or duplication.

### 6.3. Rebalances and Retries

**Handling rebalances:**

```java
consumer.subscribe(topics, new ConsumerRebalanceListener() {
    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        // Commit before losing partitions
        consumer.commitSync(currentOffsets);
        // Clean up resources
    }

    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        // Initialize state for new partitions
    }
});
```

**Handling retriable errors:**

**Option 1: Pause and retry**
```java
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        try {
            processRecord(record);
        } catch (RetriableException e) {
            // Store problematic record
            buffer.add(record);
            // Pause partition
            consumer.pause(Collections.singleton(
                new TopicPartition(record.topic(), record.partition())
            ));
            // Retry later
            retryBuffered();
        }
    }
    consumer.commitSync();
}
```

**Option 2: Dead letter queue**
```java
for (ConsumerRecord<String, String> record : records) {
    try {
        processRecord(record);
    } catch (RetriableException e) {
        // Send to retry topic
        producer.send(new ProducerRecord<>("retry-topic", record.value()));
    }
}
// Separate consumer processes retry topic
```

**Stateful processing:**
```
Challenge:
├── Need state across poll() calls (aggregations, windows)
├── Must recover state after failure
└── Must commit state and offsets together

Solution:
├── Write state to "results" topic
├── Write offsets at same time
├── On restart, read latest state from results topic
└── Or use Kafka Streams (handles this automatically)
```

> **💡 Insight**
>
> For complex stateful processing, use Kafka Streams instead of raw consumers. It handles offset management, state recovery, and exactly-once semantics for you.

---

## 7. Validating System Reliability

**In plain English:** Trust but verify - just because your system should be reliable doesn't mean it is. Test it under realistic failure conditions before production.

### 7.1. Validating Configuration

**Use Kafka's built-in tools:**

**VerifiableProducer:**
```bash
kafka-verifiable-producer \
    --bootstrap-server localhost:9092 \
    --topic test \
    --max-messages 100000 \
    --acks all

# Prints success/error for each message
```

**VerifiableConsumer:**
```bash
kafka-verifiable-consumer \
    --bootstrap-server localhost:9092 \
    --topic test \
    --group-id test-group

# Prints messages consumed in order
# Prints commit and rebalance info
```

**Test scenarios:**

1. **Leader election**
   ```
   Test: Kill partition leader
   Verify:
   ├── How long until new leader elected?
   ├── Do messages continue?
   └── Any messages lost?
   ```

2. **Controller election**
   ```
   Test: Restart controller broker
   Verify:
   ├── How long until new controller elected?
   ├── Cluster remains operational?
   └── All partitions accessible?
   ```

3. **Rolling restart**
   ```
   Test: Restart brokers one by one
   Verify:
   ├── Zero messages lost?
   ├── Continuous operation?
   └── Consumer lag acceptable?
   ```

4. **Unclean leader election**
   ```
   Test: Kill replicas one-by-one until all out-of-sync
   Then: Start an out-of-sync broker
   Verify:
   ├── How to resume operations?
   ├── Acceptable behavior?
   └── Data loss documented?
   ```

> **💡 Insight**
>
> The verifiable producer/consumer pattern is the same one used in Kafka's own test suite. If it's good enough for testing Kafka itself, it's good enough for testing your configuration.

### 7.2. Validating Applications

**Application-level testing:**

Test your actual application code, not just the Kafka configuration:

**Test scenarios:**
1. Client loses connectivity to broker
2. High latency between client and broker
3. Disk full on broker
4. Disk hangs ("brown out")
5. Leader election during processing
6. Rolling broker restart
7. Rolling consumer restart
8. Rolling producer restart

**Tools for fault injection:**
- **Kafka's Trogdor** - Built-in fault injection framework
- **Chaos engineering tools** - Chaos Monkey, Gremlin, etc.
- **Network simulation** - tc (Linux), Docker network controls

**Example test plan:**
```
Test: Rolling consumer restart
Expected:
├── Short pause during rebalance
├── No duplicates (with proper offset commit)
├── Resume from correct offset
└── No messages lost

Actual:
├── Rebalance took 2.3 seconds
├── 47 duplicates (need to fix commit timing!)
├── Resumed correctly
└── No message loss
```

### 7.3. Monitoring in Production

**Producer metrics:**

```
Key JMX metrics:
├── record-error-rate (errors per second)
├── record-retry-rate (retries per second)
└── Monitor producer logs for:
    ├── "retrying (X attempts left)" (WARN)
    └── "0 attempts left" (ERROR)
```

**Consumer metrics:**

```
Most critical: Consumer lag
├── Measures how far behind latest message
├── Should fluctuate but not grow
└── Growing lag = Can't keep up

Tools:
├── Burrow (LinkedIn's lag checker)
├── Kafka's own consumer group CLI
└── Prometheus + Grafana dashboards
```

**End-to-end monitoring:**

```
Track:
1. Messages produced per second (at source)
2. Messages consumed per second (at destination)
3. Lag from produce time to consume time

Verify:
├── All produced messages are consumed
├── Consumed within acceptable time window
└── Reconcile counts match

Requires:
├── Producer to record count
├── Consumer to record count + lag
└── System to reconcile the numbers
```

**Broker metrics:**

```
Error responses from brokers:
├── kafka.server:type=BrokerTopicMetrics,
    name=FailedProduceRequestsPerSec
├── kafka.server:type=BrokerTopicMetrics,
    name=FailedFetchRequestsPerSec

Some errors are expected (during maintenance)
└── But unexplained increases need investigation
```

> **💡 Insight**
>
> End-to-end monitoring is hard but essential. Commercial tools like Confluent Control Center provide this, but you can build it yourself by instrumenting producers and consumers to report metrics to a central system.

---

## 8. Summary

**The reliability stack:**

```
Layer 1: Broker Configuration
├── Replication factor (redundancy)
├── min.insync.replicas (minimum safety)
└── unclean.leader.election (consistency vs availability)

Layer 2: Producer Configuration
├── acks=all (wait for replication)
├── enable.idempotence=true (no duplicates)
└── delivery.timeout.ms (retry window)

Layer 3: Consumer Configuration
├── enable.auto.commit (or manual commit)
├── Commit after processing (not before)
└── Handle rebalances gracefully

Layer 4: Validation
├── Test configuration with verifiable tools
├── Test application under failure conditions
└── Monitor metrics in production
```

**Key patterns:**

**Maximum reliability:**
```
Brokers:
├── replication.factor = 3
├── min.insync.replicas = 2
└── unclean.leader.election.enable = false

Producers:
├── acks = all
├── enable.idempotence = true
└── delivery.timeout.ms = 120000

Consumers:
├── enable.auto.commit = false
├── Commit after processing
└── Handle rebalances with listeners
```

**Balanced reliability and performance:**
```
Brokers:
├── replication.factor = 3
├── min.insync.replicas = 2
└── unclean.leader.election.enable = false

Producers:
├── acks = all
├── enable.idempotence = true
├── linger.ms = 10 (batching)
└── compression.type = lz4

Consumers:
├── enable.auto.commit = true
├── auto.commit.interval.ms = 5000
└── Process in poll loop
```

**Key takeaway:** Reliability is achieved through layered defense. Each layer - brokers, producers, consumers - must be configured correctly. A chain is only as strong as its weakest link, so test the entire system, not just individual components.

**Pro tip:** Document your reliability requirements first, then work backwards to configuration:
1. Can you tolerate data loss? → Determines acks and min.insync.replicas
2. Can you tolerate duplicates? → Determines idempotence and commit strategy
3. Can you tolerate unavailability? → Determines unclean leader election
4. What's your latency requirement? → Determines batching and replication settings

---

**Previous:** [Chapter 6: Kafka Internals](./chapter6.md) | **Next:** [Chapter 8: Exactly-Once Semantics →](./chapter8.md)
