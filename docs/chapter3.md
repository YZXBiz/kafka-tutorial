# 3. Kafka Producers: Writing Messages to Kafka

> **In plain English:** A Kafka producer is like a mail sender - it packages up your data (messages) and sends them to the Kafka post office (broker) for delivery to the right mailbox (topic/partition).
>
> **In technical terms:** A Kafka producer is a client application that publishes (writes) records to Kafka topics, handling serialization, partitioning, and reliable delivery.
>
> **Why it matters:** Producers are the entry point for all data flowing into Kafka. Understanding how to configure and use them correctly determines whether your data arrives reliably, quickly, and in the right order.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Producer Overview](#2-producer-overview)
   - 2.1. [How the Producer Works](#21-how-the-producer-works)
   - 2.2. [Constructing a Producer](#22-constructing-a-producer)
3. [Sending Messages](#3-sending-messages)
   - 3.1. [Fire-and-Forget](#31-fire-and-forget)
   - 3.2. [Synchronous Send](#32-synchronous-send)
   - 3.3. [Asynchronous Send](#33-asynchronous-send)
4. [Configuring Producers](#4-configuring-producers)
   - 4.1. [Core Configurations](#41-core-configurations)
   - 4.2. [Message Delivery Time](#42-message-delivery-time)
   - 4.3. [Ordering Guarantees](#43-ordering-guarantees)
   - 4.4. [Performance Tuning](#44-performance-tuning)
5. [Serializers](#5-serializers)
   - 5.1. [Custom Serializers](#51-custom-serializers)
   - 5.2. [Apache Avro](#52-apache-avro)
6. [Partitions and Keys](#6-partitions-and-keys)
   - 6.1. [How Partitioning Works](#61-how-partitioning-works)
   - 6.2. [Custom Partitioners](#62-custom-partitioners)
7. [Advanced Features](#7-advanced-features)
   - 7.1. [Headers](#71-headers)
   - 7.2. [Interceptors](#72-interceptors)
   - 7.3. [Quotas and Throttling](#73-quotas-and-throttling)
8. [Summary](#8-summary)

---

## 1. Introduction

Every application that uses Kafka starts by writing data to it. Whether you're recording user activities, capturing metrics, storing logs, or buffering data before database writes, you need a Kafka producer.

**In plain English:** Think of a producer as the entry gate to your data pipeline - everything that goes into Kafka must pass through a producer first.

> **💡 Insight**
>
> Different use cases have different requirements. A credit card transaction system cannot afford to lose a single message or duplicate any, but a website analytics system might tolerate some message loss if it means users don't experience any delay. Understanding your requirements shapes how you configure your producer.

### 1.1. Common Use Cases

**Critical financial transactions:**
- Requirement: Zero message loss, zero duplicates, low latency (under 500ms acceptable)
- Throughput: Up to millions of messages/second

**Website clickstream:**
- Requirement: Some loss tolerable, duplicates acceptable, no user-facing latency
- Throughput: Varies with traffic

---

## 2. Producer Overview

Before diving into code, let's understand what happens when you send a message to Kafka.

### 2.1. How the Producer Works

**The journey of a message:**

```
Step 1: Create ProducerRecord
        (topic, optional partition, optional key, value)
        ↓
Step 2: Serialize key and value to byte arrays
        ↓
Step 3: Determine partition (if not specified)
        ↓
Step 4: Add to batch for that topic-partition
        ↓
Step 5: Separate thread sends batch to broker
        ↓
Step 6: Broker responds (success or error)
        ↓
Step 7: Producer handles response (retry if needed)
```

**Visual representation:**

```
ProducerRecord Creation
        ↓
[Key Serializer] [Value Serializer]
        ↓
   Partitioner
        ↓
Record Accumulator (batches by partition)
        ↓
Sender Thread → Network → Kafka Broker
        ↓
Response (RecordMetadata or Error)
```

> **💡 Insight**
>
> The producer batches messages for efficiency - it's like waiting to fill a delivery truck instead of making separate trips for each package. This dramatically improves throughput but adds a small amount of latency.

### 2.2. Constructing a Producer

**Minimal producer setup:**

```java
Properties props = new Properties();
props.put("bootstrap.servers", "broker1:9092,broker2:9092");
props.put("key.serializer",
    "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer",
    "org.apache.kafka.common.serialization.StringSerializer");

KafkaProducer<String, String> producer = new KafkaProducer<>(props);
```

**Three mandatory properties:**

1. **bootstrap.servers**: Initial connection points to Kafka cluster
   - List at least 2-3 brokers for resilience
   - Producer discovers other brokers automatically

2. **key.serializer**: Converts keys to bytes
   - Must match the actual key type you send
   - Common: StringSerializer, IntegerSerializer, ByteArraySerializer

3. **value.serializer**: Converts values to bytes
   - Must match the actual value type you send
   - Same options as key serializer

**In plain English:** Think of serializers as translators - they convert your Java objects into a format (bytes) that Kafka understands and can store.

---

## 3. Sending Messages

Once you have a producer, there are three ways to send messages, each with different trade-offs.

### 3.1. Fire-and-Forget

**What it does:** Send the message and immediately continue without waiting for confirmation.

```java
ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "Precision Products", "France");
try {
    producer.send(record);
} catch (Exception e) {
    e.printStackTrace(); // Only catches errors before sending
}
```

**When to use:**
- Message loss is acceptable
- Maximum throughput needed
- Non-critical logging or metrics

**Risks:**
- Network failures won't be detected
- Broker errors won't be caught
- Messages can disappear silently

> **💡 Insight**
>
> Fire-and-forget is rarely used in production applications. Even for non-critical data, it's usually worth knowing if your producer is completely broken rather than silently losing all messages.

### 3.2. Synchronous Send

**What it does:** Wait for Kafka to confirm receipt before continuing.

```java
ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "Precision Products", "France");
try {
    RecordMetadata metadata = producer.send(record).get(); // Blocks here
    System.out.printf("Sent to partition %d, offset %d%n",
        metadata.partition(), metadata.offset());
} catch (Exception e) {
    e.printStackTrace();
}
```

**Trade-off analysis:**

```
Synchronous:
+ Every error is caught and handled
+ Simple to understand and debug
- Very slow (2-500ms per message)
- Throughput = 1/latency (500ms latency = 2 msgs/sec maximum)

Asynchronous:
+ Much higher throughput
+ Non-blocking
- More complex error handling
- Requires callbacks
```

**When to use:**
- Learning/testing
- Truly critical messages where order matters more than speed
- Low-volume use cases

### 3.3. Asynchronous Send

**What it does:** Send the message and provide a callback for when Kafka responds.

```java
private class DemoProducerCallback implements Callback {
    @Override
    public void onCompletion(RecordMetadata metadata, Exception e) {
        if (e != null) {
            e.printStackTrace(); // Handle error
        } else {
            System.out.printf("Message sent to partition %d, offset %d%n",
                metadata.partition(), metadata.offset());
        }
    }
}

ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "Biomedical Materials", "USA");
producer.send(record, new DemoProducerCallback());
```

**How it works:**

```
Main Thread              Callback Thread
    |                           |
send(record, callback)          |
    |                           |
    | (continues immediately)   |
    |                           |
send(next record)               |
    |                           |
    |                    [Kafka responds]
    |                           |
    |                    callback.onCompletion()
    |                           |
```

> **💡 Insight**
>
> Callbacks execute in the producer's I/O thread, which means they should be fast. Don't perform blocking operations (like database writes) in callbacks - spawn a new thread if you need to do heavy work based on the callback result.

**When to use:**
- Production applications (most common pattern)
- Need high throughput with error handling
- Can process responses asynchronously

---

## 4. Configuring Producers

The producer has dozens of configuration options. We'll focus on the most impactful ones.

### 4.1. Core Configurations

#### client.id

**Purpose:** Identifies this producer in logs, metrics, and quotas

```java
props.put("client.id", "order-validation-service");
```

**Impact:**
```
Without client.id:
"High error rate from IP 104.27.155.134"
(Which service? Which team owns it?)

With client.id:
"Order Validation service is failing to authenticate"
(Clear ownership, faster response)
```

#### acks

**Purpose:** Controls durability vs. latency trade-off

**Three options:**

```
acks=0 (Don't wait for any acknowledgment)
Producer → Broker
         ← [No response]
Latency: Minimal
Durability: None (messages can be lost)

acks=1 (Wait for leader to write)
Producer → Leader Broker
         ← Success (once written to leader)
Latency: Low (~2-10ms)
Durability: Medium (lost if leader crashes before replication)

acks=all (Wait for all in-sync replicas)
Producer → Leader → Replica 1 → Replica 2
         ← Success (all confirmed)
Latency: Higher (~5-50ms)
Durability: Highest (survives broker failures)
```

> **💡 Insight**
>
> Interestingly, end-to-end latency (producer to consumer) is the same for all three acks settings! Consumers can't read messages until they're replicated to all in-sync replicas anyway. The difference is only in producer latency - how long the producer waits before considering the message sent.

**Recommendation:** Use `acks=all` for production unless you have specific reasons otherwise.

### 4.2. Message Delivery Time

**Understanding timeouts:**

```
Time Split: [send() blocks] → [async operation until callback]
                ↑                        ↑
          max.block.ms          delivery.timeout.ms
```

#### max.block.ms

**Controls:** How long `send()` can block waiting for buffer space or metadata

```java
props.put("max.block.ms", "60000"); // 60 seconds
```

**When it blocks:**
- Send buffer is full (producing faster than network can send)
- Waiting for topic metadata (first send to a topic)

**Default:** 60 seconds

#### delivery.timeout.ms

**Controls:** Total time for async operation (from ready-to-send until success or failure)

```java
props.put("delivery.timeout.ms", "120000"); // 2 minutes
```

**Includes:**
- Time in batch accumulator
- Time waiting to send
- All retry attempts
- Network round trips

**Default:** 120 seconds

> **💡 Insight**
>
> Modern best practice: Set `delivery.timeout.ms` to the maximum time you're willing to wait (e.g., 120 seconds to allow for leader election during broker failure), and leave retries at default (essentially infinite within that time). This is much simpler than calculating the right number of retries.

#### request.timeout.ms

**Controls:** How long to wait for each individual request

```java
props.put("request.timeout.ms", "30000"); // 30 seconds
```

**Default:** 30 seconds

**Relationship:**
```
delivery.timeout.ms (120s total)
    └─> request.timeout.ms (30s per attempt)
            └─> Can retry 4 times before total timeout
```

### 4.3. Ordering Guarantees

**The problem:**

```
Message A sent → [Network error]
Message B sent → [Success!]
Retry Message A → [Success!]

Result on broker: B, A (WRONG ORDER!)
```

**The solution:** `enable.idempotence=true`

```java
props.put("enable.idempotence", "true");
```

**What it does:**
- Assigns sequence numbers to messages
- Broker detects and ignores duplicates
- Guarantees ordering even with retries
- Allows up to 5 in-flight requests (for performance)

**Requirements:**
- `max.in.flight.requests.per.connection` ≤ 5
- `retries` > 0
- `acks=all`

> **💡 Insight**
>
> Idempotence is Kafka's solution to the "exactly-once semantics" problem for producers. The broker can tell if it already received a message (via sequence number) and safely ignore duplicates, while maintaining message order.

### 4.4. Performance Tuning

#### linger.ms

**Purpose:** How long to wait for more messages before sending a batch

```java
props.put("linger.ms", "10"); // Wait up to 10ms
```

**Trade-off:**

```
linger.ms = 0 (default)
Message arrives → Send immediately
+ Lowest latency
- Many small batches
- Lower throughput
- Less compression efficiency

linger.ms = 10-100
Message arrives → Wait for more → Send batch
+ Better throughput (fewer, larger batches)
+ Better compression
- Slightly higher latency (10-100ms)
```

**Recommendation:** Set to 10-100ms for high-throughput applications.

#### batch.size

**Purpose:** Maximum bytes in a batch (not maximum number of messages)

```java
props.put("batch.size", "16384"); // 16 KB (default)
```

**How it works:**
- Doesn't wait for batch to fill
- Sends when batch is full OR linger.ms expires
- Separate batch per partition

**Bigger batches:**
- Better compression
- Better throughput
- More memory used

**Recommendation:** Increase for high-throughput scenarios (32KB-128KB).

#### compression.type

**Purpose:** Compress batches before sending

```java
props.put("compression.type", "snappy"); // or gzip, lz4, zstd
```

**Options comparison:**

```
snappy: Fast compression, decent ratio
├─ CPU: Low
├─ Ratio: Moderate (2-3x)
└─ Use: Balanced (default recommendation)

gzip: Slower compression, better ratio
├─ CPU: High
├─ Ratio: Good (3-5x)
└─ Use: Network bandwidth constrained

lz4: Fastest compression, moderate ratio
├─ CPU: Very Low
├─ Ratio: Moderate (2-3x)
└─ Use: CPU constrained

zstd: Best compression, moderate speed
├─ CPU: Medium
├─ Ratio: Best (3-6x)
└─ Use: Latest, most balanced option
```

---

## 5. Serializers

Kafka stores and transmits bytes. Serializers convert your objects to bytes.

### 5.1. Custom Serializers

**Example: Serializing a Customer object**

```java
public class Customer {
    private int customerID;
    private String customerName;

    // constructors, getters...
}
```

**Custom serializer:**

```java
public class CustomerSerializer implements Serializer<Customer> {

    @Override
    public byte[] serialize(String topic, Customer data) {
        try {
            if (data == null) return null;

            byte[] serializedName = data.getName().getBytes("UTF-8");
            int stringSize = serializedName.length;

            // Format: [4 bytes: ID][4 bytes: name length][N bytes: name]
            ByteBuffer buffer = ByteBuffer.allocate(4 + 4 + stringSize);
            buffer.putInt(data.getID());
            buffer.putInt(stringSize);
            buffer.put(serializedName);

            return buffer.array();
        } catch (Exception e) {
            throw new SerializationException("Error serializing Customer", e);
        }
    }
}
```

**Problems with custom serializers:**

```
Version 1: [CustomerID][CustomerName]
    ↓
Add field to Customer class
    ↓
Version 2: [CustomerID][CustomerName][StartDate]
    ↓
Old consumers break! Can't read new format.
New consumers break! Can't read old format.
```

> **💡 Insight**
>
> Custom serializers create tight coupling between producers and consumers. Any schema change requires coordinated deployment of all services. This is why standardized formats with schema evolution support are strongly recommended.

### 5.2. Apache Avro

**Why Avro:**
- Self-describing data format
- Schema evolution support (add/remove fields safely)
- Compact binary format
- Schema registry validates compatibility

**Avro schema example:**

```json
{
  "namespace": "customerManagement.avro",
  "type": "record",
  "name": "Customer",
  "fields": [
    {"name": "id", "type": "int"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": ["null", "string"], "default": null}
  ]
}
```

**Using Avro with Kafka:**

```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("key.serializer",
    "io.confluent.kafka.serializers.KafkaAvroSerializer");
props.put("value.serializer",
    "io.confluent.kafka.serializers.KafkaAvroSerializer");
props.put("schema.registry.url", schemaUrl); // Where schemas are stored

Producer<String, Customer> producer = new KafkaProducer<>(props);

// Avro-generated Customer object
Customer customer = CustomerGenerator.getNext();
ProducerRecord<String, Customer> record =
    new ProducerRecord<>("customerContacts", customer.getName(), customer);
producer.send(record);
```

**How it works:**

```
Producer                Schema Registry              Kafka Broker
    |                           |                          |
    |--1. Register schema------>|                          |
    |<-----schema ID ----------|                          |
    |                           |                          |
    |--2. Send: [schema ID][data]------------------------->|
                                                           |
Consumer                                                   |
    |                                                      |
    |--3. Fetch message: [schema ID][data]----------------|
    |
    |--4. Get schema by ID----->|
    |<-----schema-------------- |
    |
    |--5. Deserialize data
```

**Schema evolution example:**

```
Old schema (v1):
{fields: [id, name, faxNumber]}

New schema (v2):
{fields: [id, name, email]}

Old consumer reading new data:
├─ Reads: id, name, email
├─ Accesses: id ✓, name ✓, faxNumber (returns null) ✓
└─ Works! No errors.

New consumer reading old data:
├─ Reads: id, name, faxNumber
├─ Accesses: id ✓, name ✓, email (returns null) ✓
└─ Works! No errors.
```

---

## 6. Partitions and Keys

Messages are distributed across partitions. Understanding how this works is crucial.

### 6.1. How Partitioning Works

**Creating records with and without keys:**

```java
// With key (same key always goes to same partition)
ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "Precision Products", "France");

// Without key (round-robin across partitions)
ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "France");
```

**Partitioning logic:**

```
If key == null:
    └─> Round-robin across available partitions
              (sticky: fills batch before switching partitions)

If key != null:
    └─> partition = hash(key) % numPartitions
              (deterministic: same key → same partition)
```

**Example with 4 partitions:**

```
Records:
├─ (key="user123", value="login")     → hash("user123") % 4 = Partition 2
├─ (key="user456", value="purchase")  → hash("user456") % 4 = Partition 1
├─ (key="user123", value="logout")    → hash("user123") % 4 = Partition 2
└─ (key=null, value="anonymous")      → Round-robin → Partition 3

Partition 0: []
Partition 1: [(user456, purchase)]
Partition 2: [(user123, login), (user123, logout)]  ← Same key, same partition!
Partition 3: [(null, anonymous)]
```

> **💡 Insight**
>
> Consistent hashing of keys to partitions is what makes Kafka so powerful for stateful processing. All events for user123 go to partition 2, so a single consumer can maintain state for that user without coordination with other consumers.

**Important warning:**

```
Topic with 4 partitions:
user123 → partition 2 ✓

Add 2 partitions (now 6 total):
user123 → partition 5 ✗ (different partition!)

Old messages for user123: partition 2
New messages for user123: partition 5
└─> Order broken! State scattered!
```

**Best practice:** Choose partition count carefully at creation time. Avoid adding partitions if keys matter.

### 6.2. Custom Partitioners

**Use case:** Special customer needs special handling

```
Problem:
├─ Customer "Banana" = 10% of all transactions
├─ Default partitioning: Banana shares partition with others
└─> One partition much larger than others (imbalanced)

Solution:
├─ Give Banana its own partition
└─> Balance all others across remaining partitions
```

**Implementation:**

```java
public class BananaPartitioner implements Partitioner {

    public int partition(String topic, Object key, byte[] keyBytes,
                         Object value, byte[] valueBytes, Cluster cluster) {

        List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
        int numPartitions = partitions.size();

        if (keyBytes == null || !(key instanceof String))
            throw new InvalidRecordException("Expecting String key");

        // Special customer gets last partition
        if (((String) key).equals("Banana"))
            return numPartitions - 1;

        // Everyone else hashed to remaining partitions
        return Math.abs(Utils.murmur2(keyBytes)) % (numPartitions - 1);
    }
}
```

**Using custom partitioner:**

```java
props.put("partitioner.class", "com.example.BananaPartitioner");
```

---

## 7. Advanced Features

### 7.1. Headers

**Purpose:** Add metadata without modifying key/value

```java
ProducerRecord<String, String> record =
    new ProducerRecord<>("CustomerCountry", "Precision Products", "France");

record.headers().add("privacy-level", "YOLO".getBytes(StandardCharsets.UTF_8));
record.headers().add("source-system", "mobile-app".getBytes(StandardCharsets.UTF_8));
```

**Common uses:**
- Lineage tracking (where did this data come from?)
- Routing hints
- Security metadata
- Tracing IDs

### 7.2. Interceptors

**Purpose:** Modify producer behavior without changing application code

```java
public class CountingProducerInterceptor implements ProducerInterceptor {

    static AtomicLong numSent = new AtomicLong(0);
    static AtomicLong numAcked = new AtomicLong(0);

    public ProducerRecord onSend(ProducerRecord record) {
        numSent.incrementAndGet();
        return record; // Can modify record here
    }

    public void onAcknowledgement(RecordMetadata metadata, Exception e) {
        numAcked.incrementAndGet(); // Can log metrics here
    }
}
```

**Configuration (no code changes needed):**

```properties
interceptor.classes=com.example.CountingProducerInterceptor
```

**Common uses:**
- Monitoring and metrics
- Audit logging
- Adding standard headers
- Data masking/redaction

### 7.3. Quotas and Throttling

**Purpose:** Prevent producers from overwhelming the cluster

**Setting quotas dynamically:**

```bash
# Limit specific client to 1024 bytes/sec
bin/kafka-configs --bootstrap-server localhost:9092 \
  --alter --add-config 'producer_byte_rate=1024' \
  --entity-name clientC --entity-type clients

# Limit user to 1024 bytes/sec produce, 2048 bytes/sec consume
bin/kafka-configs --bootstrap-server localhost:9092 \
  --alter --add-config 'producer_byte_rate=1024,consumer_byte_rate=2048' \
  --entity-name user1 --entity-type users
```

**What happens when quota exceeded:**

```
Producer sending too fast
    ↓
Broker throttles responses (delays them)
    ↓
Producer has in-flight request limit
    ↓
Can't send more requests until responses arrive
    ↓
Automatically slows down to match quota
```

**Monitoring throttling:**

```
Metrics:
├─ produce-throttle-time-avg: Average delay due to throttling
├─ produce-throttle-time-max: Maximum delay
└─ If > 0: You're being throttled!
```

---

## 8. Summary

**What we learned:**

1. **Producer Architecture**: Messages flow through serialization → partitioning → batching → network → broker

2. **Three Send Methods**:
   - Fire-and-forget: Fast, no guarantees
   - Synchronous: Slow, reliable
   - Asynchronous: Fast and reliable (production choice)

3. **Critical Configurations**:
   - `acks=all` for durability
   - `enable.idempotence=true` for ordering
   - `delivery.timeout.ms` for retry control
   - `linger.ms` and `batch.size` for throughput

4. **Serialization**:
   - Custom serializers are fragile
   - Use Avro for schema evolution
   - Schema Registry validates compatibility

5. **Partitioning**:
   - Null keys → round-robin
   - Non-null keys → consistent hashing
   - Adding partitions breaks key-to-partition mapping

6. **Advanced Features**:
   - Headers for metadata
   - Interceptors for cross-cutting concerns
   - Quotas for resource protection

**Key takeaway:** Producer configuration is about balancing three competing concerns: durability (don't lose data), throughput (send lots of data fast), and ordering (keep data in sequence). Understanding these trade-offs lets you configure the producer correctly for your use case.

---

**Previous:** [Chapter 2: Installing Kafka](./chapter2.md) | **Next:** [Chapter 4: Kafka Consumers →](./chapter4.md)
