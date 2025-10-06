# 8. Exactly-Once Semantics

> **In plain English:** Exactly-once semantics is like having a perfect postal system where every letter is delivered exactly once - no lost mail, no duplicates, even if trucks crash or addresses get confused.
>
> **In technical terms:** Exactly-once semantics ensures that each input record in a stream processing application is processed exactly one time, with results reflected exactly once in the output, even under failure conditions.
>
> **Why it matters:** In financial applications, processing a payment twice can have serious consequences. Exactly-once guarantees mean you can build aggregations, joins, and transformations that produce correct results even when failures occur.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Idempotent Producer](#2-idempotent-producer)
   - 2.1. [How It Works](#21-how-it-works)
   - 2.2. [Failure Scenarios](#22-failure-scenarios)
   - 2.3. [Limitations](#23-limitations)
   - 2.4. [How to Use It](#24-how-to-use-it)
3. [Transactions](#3-transactions)
   - 3.1. [Use Cases](#31-use-cases)
   - 3.2. [Problems Transactions Solve](#32-problems-transactions-solve)
   - 3.3. [How Transactions Work](#33-how-transactions-work)
   - 3.4. [Problems Transactions Don't Solve](#34-problems-transactions-dont-solve)
   - 3.5. [How to Use Transactions](#35-how-to-use-transactions)
   - 3.6. [Performance Considerations](#36-performance-considerations)
4. [Summary](#4-summary)

---

## 1. Introduction

**In plain English:** At-least-once delivery means "I guarantee the message arrives, but it might arrive twice." Exactly-once means "I guarantee the message arrives exactly one time, no more, no less."

Chapter 7 covered at-least-once delivery - ensuring Kafka doesn't lose acknowledged messages. But at-least-once still allows duplicates, which become problematic when:

**Simple systems:**
- Single record transformations → Duplicates annoying but manageable
- Unique IDs exist → Easy to deduplicate downstream

**Complex systems:**
- Aggregations → Can't tell if result is wrong due to duplicate input
- Joins → Duplicates corrupt the join results
- Financial calculations → Counting money twice has serious consequences

> **💡 Insight**
>
> Exactly-once isn't about individual message delivery - it's about ensuring stream processing applications produce correct results even when retries and failures occur.

**Two key features enable exactly-once:**

1. **Idempotent producers** - Prevent duplicates from retries
2. **Transactions** - Atomic consume-process-produce operations

---

## 2. Idempotent Producer

**In plain English:** Idempotent means doing something multiple times has the same effect as doing it once - like pressing an elevator button repeatedly; the elevator still only comes once.

### 2.1. How It Works

**The duplicate problem:**
```
Timeline:
1. Producer sends message to leader
2. Leader replicates successfully
3. Leader crashes before sending ack
4. Producer doesn't get acknowledgment
5. Producer retries (sends again)
6. New leader receives duplicate
└── Message appears twice in partition
```

**The idempotent solution:**

```
Each message includes:
├── Producer ID (PID) - Unique identifier
├── Sequence number - Increments per message
└── Topic + Partition

Together these uniquely identify each message
```

**Broker deduplication:**
```
Broker tracks last 5 sequence numbers per producer per partition

Message arrives:
├── Check: Already seen this PID + sequence?
│   ├── Yes → Reject with appropriate error (not visible to user)
│   └── No → Accept and store
└── Update tracking
```

**Visual flow:**
```
Producer (PID=123):
├── Message 1 (seq=1) → Broker accepts
├── Message 2 (seq=2) → Broker accepts
├── <Leader crashes before ack>
├── Message 2 (seq=2) → Broker rejects (duplicate!)
└── Producer logs error but continues normally
```

> **💡 Insight**
>
> The duplicate rejection is transparent. The producer logs it and updates metrics, but the application doesn't see an exception. From the application's perspective, the message was sent successfully once.

**Sequence gap detection:**
```
Broker expects: seq=2
Broker receives: seq=27

Broker response: "Out of order sequence"

Without transactions:
└── This error is logged but ignored
    (Indicates possible message loss, worth investigating)

With transactions:
└── This error causes transaction abort
    (Prevents data corruption)
```

### 2.2. Failure Scenarios

**Producer restart:**
```
Old producer (PID=123) sends messages 1-5
Producer crashes and restarts
New producer gets new PID=456
Sends same messages with PID=456, seq=1-5

Broker sees:
├── PID=123, seq=1-5 (from old producer)
└── PID=456, seq=1-5 (from new producer)
    └── Different PIDs = Not duplicates
        └── Both messages stored
```

**Key point:** Producer restart breaks duplicate detection because new PID is generated.

**Broker failure:**
```
Producer sends to Leader (Broker 5):
├── Broker 5 tracks PID + sequence in memory
├── Follower (Broker 3) replicates and tracks too
└── Broker 5 fails

Broker 3 becomes new leader:
├── Already has sequence tracking in memory
├── Duplicate detection continues seamlessly
└── No gap in protection
```

**Broker crash and restart:**
```
Broker crashes (loses in-memory state):
1. Reads latest snapshot from disk
2. Replays messages from latest segment
3. Rebuilds producer state
4. Creates new snapshot
└── Ready to detect duplicates again

If no recent messages:
├── Broker can't recover state (no data to read)
├── Logs warning but continues
└── No duplicates possible (no messages to duplicate)
```

> **💡 Insight**
>
> The producer state is part of the message format on disk. This elegant design means broker recovery doesn't require external state - everything is in the log.

### 2.3. Limitations

**What idempotent producer prevents:**
```
✓ Duplicates from producer retries
✓ Duplicates from network issues
✓ Duplicates from broker failures
```

**What it doesn't prevent:**
```
✗ Application calling send() twice with same data
✗ Multiple producer instances sending same data
✗ Producer restart sending same data
```

**Example problematic scenario:**
```
Application reads files and produces to Kafka:
├── Instance 1 reads file.txt
├── Instance 2 reads file.txt (accidentally)
└── Both produce same records
    └── Idempotent producer sees different PIDs
        └── Can't detect duplicates
```

> **💡 Insight**
>
> Idempotent producer prevents duplicates from the retry mechanism only. It doesn't make your application idempotent. Design your applications carefully to avoid creating duplicates at the source.

### 2.4. How to Use It

**Configuration:**
```properties
enable.idempotence=true
```

**What changes:**

1. **Startup:** One extra API call to get Producer ID

2. **Messages:** Each batch includes:
   - Producer ID (long): 64 bits
   - Sequence number (int): 32 bits
   - Total overhead: 96 bits per batch (minimal!)

3. **Broker:** Validates sequences, deduplicates automatically

4. **Ordering:** Guaranteed even with `max.in.flight.requests > 1`
   - Previously needed `max.in.flight.requests=1` for ordering
   - Now can use default of 5 for better performance

**Compatibility:**
```
Works with:
├── acks=all (no performance difference)
├── max.in.flight.requests.per.connection ≤ 5
└── Kafka 0.11+ brokers
```

> **💡 Insight**
>
> Version 2.5 fixed many edge cases with idempotent producers. If using older versions, upgrade to 2.5+ for more reliable behavior, especially around partition reassignment and unknown producer ID errors.

---

## 3. Transactions

**In plain English:** Transactions are like a restaurant order where the kitchen either prepares your entire meal or none of it - no half-cooked orders served to customers.

### 3.1. Use Cases

**Primary use case: Stream processing**
```
Consume → Process → Produce pattern:
├── Read from input topic
├── Transform/aggregate/join
├── Write to output topic
└── Commit offset

Exactly-once guarantee:
└── Either all happen or none happen
    └── No partial results
```

**When transactions are essential:**

1. **Aggregations**
   ```
   Count page views by user:
   ├── Without exactly-once: Count might be wrong (duplicates)
   └── With exactly-once: Count is accurate
   ```

2. **Joins**
   ```
   Join user profiles with purchases:
   ├── Without exactly-once: Join results corrupted by duplicates
   └── With exactly-once: Join results accurate
   ```

3. **Financial applications**
   ```
   Calculate account balances:
   ├── Without exactly-once: Incorrect balances (disastrous!)
   └── With exactly-once: Correct balances guaranteed
   ```

**When transactions less critical:**

```
Simple transformations and filtering:
├── Input: User click events
├── Process: Filter out bots
├── Output: Filtered clicks
└── Duplicates easy to filter downstream
    (Each event has unique ID)
```

> **💡 Insight**
>
> Kafka Streams makes exactly-once trivial to enable (one config setting). Because it's so easy and the overhead is minimal, many applications enable it even for simpler use cases.

### 3.2. Problems Transactions Solve

**Problem 1: Application crashes**

```
Scenario:
1. Consumer reads batch of messages
2. Application processes messages
3. Application produces results to output
4. Application crashes before committing offset
5. Rebalance assigns partition to another consumer
6. New consumer reprocesses same batch
└── Results written twice to output topic!
```

**How transactions solve it:**
```
Transactional approach:
1. Begin transaction
2. Consume and process batch
3. Produce results to output
4. Commit offset within transaction
5. Commit transaction
└── All or nothing atomicity
```

**Problem 2: Zombie applications**

```
Scenario:
1. Consumer reads batch
2. Consumer freezes (network partition)
3. Rebalance assigns partition to new consumer
4. New consumer processes batch and produces results
5. Old consumer wakes up, doesn't know it's dead
6. Zombie produces results too
└── Duplicate results from zombie!
```

**How transactions solve it:**
```
Zombie fencing:
├── Each transaction has epoch number
├── New consumer gets higher epoch
├── Broker rejects requests from old epoch
└── Zombie can't pollute output
```

> **💡 Insight**
>
> The zombie problem is subtle but real. Without fencing, a consumer that freezes for 30 seconds can wake up, think everything is fine, and corrupt your output data. Transactions prevent this.

### 3.3. How Transactions Work

**The key mechanism: Atomic multipartition writes**

```
Stream processing app:
├── Reads from topic A
├── Writes results to topic B
├── Commits offset to __consumer_offsets
└── All three must happen atomically
```

**Visual flow:**
```
Transaction:
├── Write to topic B (partition 3)
├── Write to topic B (partition 7)
├── Write to __consumer_offsets (partition 12)
└── Either all visible or none visible
```

**Components:**

**1. Transactional ID**
```
Configured on producer:
├── Persists across restarts
├── Maps to Producer ID
└── Used for zombie fencing

Example:
transactional.id = "my-app-instance-1"
```

**2. Epoch number**
```
Increments on each initTransactions():
├── Old producer: epoch 5
├── New producer: epoch 6
└── Broker rejects epoch 5 requests (zombie fencing)
```

**3. Transaction coordinator**
```
Special broker role:
├── Manages transaction log
├── Coordinates two-phase commit
└── Ensures all-or-nothing semantics
```

**4. Read isolation**
```
Consumer configuration:
isolation.level = read_committed

Behavior:
├── Sees committed transactions
├── Sees non-transactional writes
├── Doesn't see uncommitted transactions
└── Doesn't see aborted transactions
```

**Visual timeline:**
```
Producer writes:
Offset 0-10:   Committed transaction ✓
Offset 11-20:  Open transaction (in progress)
Offset 21-30:  Committed transaction ✓
Offset 31-40:  Aborted transaction ✗

read_committed consumer sees:
├── Offsets 0-10 (committed)
├── Waits at offset 11 (LSO - Last Stable Offset)
└── Can't see 21-40 until transaction at 11 commits/aborts

read_uncommitted consumer sees:
└── Everything including open/aborted transactions
```

> **💡 Insight**
>
> Holding a transaction open too long delays consumers in read_committed mode. Keep transactions short (seconds, not minutes) to maintain low end-to-end latency.

**How transactions execute:**

```
1. initTransactions()
   └── Register transactional ID, get Producer ID, bump epoch

2. beginTransaction()
   └── Local operation, coordinator not yet aware

3. send() messages
   └── First send to new partition triggers AddPartitionsToTxn
       └── Coordinator records partition in transaction log

4. sendOffsetsToTransaction()
   └── Commits consumer offsets as part of transaction

5. commitTransaction()
   ├── Send EndTransactionRequest to coordinator
   ├── Coordinator logs "commit intent" to transaction log
   ├── Coordinator writes commit markers to all partitions
   └── Coordinator logs "transaction complete"

If coordinator crashes:
└── New coordinator reads transaction log
    └── Completes any in-progress commits
```

### 3.4. Problems Transactions Don't Solve

**In plain English:** Transactions guarantee atomic writes to Kafka topics. They don't magically make external systems transactional or guarantee end-to-end exactly-once for all scenarios.

**1. Side effects**
```
Stream processing with email:
├── Read event from Kafka
├── Send email to user ← External side effect!
├── Write result to Kafka
└── Commit transaction

If transaction aborts:
├── Kafka results are rolled back
└── Email already sent (can't unsend!)

Exactly-once doesn't apply to external actions
```

**2. Writing to databases**
```
Read from Kafka → Write to PostgreSQL:
├── Can't commit both in single transaction
├── Kafka transaction != Database transaction
└── Need idempotent database writes instead

Solution: Outbox pattern
├── Write to Kafka topic (outbox)
├── Separate service reads Kafka → Updates DB
└── Make DB update idempotent
```

**3. Database to Kafka to database**
```
MySQL → Kafka → PostgreSQL:
├── Can't preserve MySQL transaction boundaries
├── Consumer may lag on some topics
├── Consumer doesn't know transaction boundaries
└── Can see partial transactions

Not supported by Kafka transactions
```

**4. Cross-cluster replication**
```
MirrorMaker copies data between clusters:
├── Can achieve exactly-once per record
└── But not preserve transaction atomicity
    └── Records might be in different transactions
```

**5. Publish/subscribe pattern**
```
Producer publishes with transaction:
├── Consumers in read_committed mode won't see aborted
└── But consumers may still process duplicates
    └── Depends on their own offset commit logic

Exactly-once applies to consume-process-produce
Not to pure publish/subscribe
```

**6. Deadlock scenario to avoid**
```
Wrong:
1. Produce message in transaction
2. Wait for another app to respond
3. Commit transaction

Problem:
└── Other app can't see message until commit
    └── Will wait forever (deadlock!)
```

> **💡 Insight**
>
> Transactions solve exactly-once for Kafka-to-Kafka stream processing. For anything involving external systems, you need additional patterns like idempotent operations or the outbox pattern.

### 3.5. How to Use Transactions

**Option 1: Kafka Streams (recommended)**

```java
Properties props = new Properties();
props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, "exactly_once_v2");

// That's it! Kafka Streams handles transactions automatically
```

**Option 2: Manual transactions**

```java
// 1. Configure transactional producer
Properties props = new Properties();
props.put("transactional.id", "my-app-1");  // Must be unique & persistent
KafkaProducer<String, String> producer = new KafkaProducer<>(props);

// 2. Configure read_committed consumer
Properties consumerProps = new Properties();
consumerProps.put("enable.auto.commit", "false");  // Manual commit
consumerProps.put("isolation.level", "read_committed");
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(consumerProps);

// 3. Initialize transactions
producer.initTransactions();  // Must be first

consumer.subscribe(Collections.singleton("input-topic"));

// 4. Processing loop
while (true) {
    try {
        // Poll for records
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));

        if (records.count() > 0) {
            // Begin transaction
            producer.beginTransaction();

            // Process and produce
            for (ConsumerRecord<String, String> record : records) {
                String result = processRecord(record);
                producer.send(new ProducerRecord<>("output-topic", result));
            }

            // Commit offsets within transaction
            Map<TopicPartition, OffsetAndMetadata> offsets = getOffsets(records);
            producer.sendOffsetsToTransaction(offsets, consumer.groupMetadata());

            // Commit transaction
            producer.commitTransaction();
        }
    } catch (ProducerFencedException | InvalidProducerEpochException e) {
        // We are a zombie - another instance took over
        throw new KafkaException("Zombie detected! Shutting down.", e);
    } catch (KafkaException e) {
        // Other error - abort and retry
        producer.abortTransaction();
        consumer.seek(partition, lastCommittedOffset);
    }
}
```

**Key APIs explained:**

```java
producer.initTransactions()
// Registers transactional.id, bumps epoch, fences zombies

producer.beginTransaction()
// Starts transaction (local operation)

producer.sendOffsetsToTransaction(offsets, groupMetadata)
// Commits consumer offsets as part of transaction
// groupMetadata enables consumer-group-based fencing (2.5+)

producer.commitTransaction()
// Two-phase commit across all partitions

producer.abortTransaction()
// Rollback - markers written to say "ignore these records"
```

**Transactional ID selection:**

```
Must be:
├── Unique per application instance
├── Consistent across restarts
└── Different for different instances

Example strategies:
├── Statically assigned: "my-app-instance-1"
├── Based on hostname: "my-app-{hostname}"
└── Based on partition: "my-app-partition-{N}"

Wrong:
└── Random ID each time (breaks fencing)
```

> **💡 Insight**
>
> Pre-2.5, you had to statically map transactional IDs to partitions for proper fencing. Since 2.5 (KIP-447), consumer group metadata handles fencing, allowing dynamic partition assignment. This makes transactional applications much easier to build.

### 3.6. Performance Considerations

**Producer overhead:**

```
Per transaction:
├── initTransactions(): One-time startup cost
├── AddPartitionsToTxn: One per new partition per transaction
└── commitTransaction(): One synchronous commit

Overhead independent of message count!
```

**Throughput optimization:**
```
Larger transactions:
├── More messages per transaction
├── Amortizes overhead
└── Higher throughput

But:
└── Longer time to commit
    └── Higher end-to-end latency
```

**Consumer impact:**

```
read_committed mode:
├── Waits for commit markers
├── Can't read open transactions
└── Higher latency but NOT lower throughput
    (No buffering needed - broker handles it)

read_uncommitted mode:
├── No wait for commits
└── Sees everything (including aborted)
```

**Memory considerations:**

```
Warning: Memory leak potential!

Each unique transactional ID creates:
├── Producer state entry in broker memory
├── Last 5 batch metadata per partition
└── Stored for transactional.id.expiration.ms (7 days default)

Creating many one-time IDs:
├── 3 new IDs/second * 7 days = 1.8M entries
├── ~5 GB RAM on broker
└── Can cause OOM or severe GC issues

Solution:
├── Reuse producers (recommended)
└── Or lower transactional.id.expiration.ms
```

> **💡 Insight**
>
> Design your application to create a few long-lived transactional producers at startup and reuse them. Avoid patterns like Function-as-a-Service where each invocation creates a new producer with a new transactional ID.

---

## 4. Summary

**What we learned:**

**1. Idempotent Producer**
- Prevents duplicates from retry mechanism
- Adds Producer ID and sequence numbers
- Minimal overhead (96 bits per batch)
- Enable with `enable.idempotence=true`
- Improved dramatically in Kafka 2.5+

**2. Transactions**
- Enable exactly-once stream processing
- Atomic consume-process-produce
- Zombie fencing via epochs
- Two isolation levels: `read_committed` and `read_uncommitted`

**3. When to use what:**

```
Idempotent Producer:
├── Producing to Kafka only
├── Want to eliminate duplicates from retries
└── No streaming or complex processing

Transactions:
├── Consume-process-produce pattern
├── Aggregations, joins, or stateful processing
└── Need exactly-once guarantees for results

Kafka Streams:
├── Complex stream processing
├── Easiest way to get exactly-once
└── Just set processing.guarantee=exactly_once_v2
```

**4. What transactions don't solve:**
- External side effects (emails, HTTP calls)
- Cross-system transactions (Kafka + database)
- Preserving source system transaction boundaries
- Pure publish/subscribe exactly-once

**Key patterns:**

**Maximum reliability:**
```java
// Producer
props.put("enable.idempotence", "true");
props.put("transactional.id", "my-app-1");

// Consumer
props.put("isolation.level", "read_committed");
props.put("enable.auto.commit", "false");

// Use beginTransaction/commitTransaction
```

**Trade-offs:**
```
Larger transactions:
├── + Higher throughput
├── + Lower overhead
└── - Higher latency

Smaller transactions:
├── + Lower latency
├── - Higher overhead
└── - Lower throughput
```

**Key takeaway:** Exactly-once semantics in Kafka is powerful but has specific use cases. It excels at Kafka-to-Kafka stream processing but doesn't solve all exactly-once scenarios. Understanding what it does and doesn't guarantee helps you design systems that work correctly.

**Pro tip:** Start with Kafka Streams for stream processing. It handles all the transaction complexity for you. Only use raw transactional API if you need fine-grained control or have requirements Kafka Streams doesn't support.

---

**Previous:** [Chapter 7: Reliable Data Delivery](./chapter7.md) | **Next:** [Chapter 9: Building Data Pipelines →](./chapter9.md)
