# 14. Stream Processing

> **In plain English:** Stream processing is like having a team of workers continuously watching a conveyor belt, examining each item as it passes, and immediately taking action—rather than waiting for thousands of items to pile up before doing anything.
>
> **In technical terms:** Stream processing refers to the ongoing, continuous processing of unbounded datasets (event streams) where transformations, aggregations, and analytics are applied to each event as it arrives, rather than in periodic batches.
>
> **Why it matters:** Modern businesses need real-time insights. Waiting hours for batch jobs means missed opportunities—fraud goes undetected, recommendations become stale, and operational issues aren't caught until it's too late. Stream processing bridges the gap between instant responses and batch analytics.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [What Is Stream Processing?](#2-what-is-stream-processing)
   - 2.1. [Understanding Data Streams](#21-understanding-data-streams)
   - 2.2. [Stream Attributes](#22-stream-attributes)
   - 2.3. [Processing Paradigms Compared](#23-processing-paradigms-compared)
3. [Stream Processing Concepts](#3-stream-processing-concepts)
   - 3.1. [Topology](#31-topology)
   - 3.2. [Time](#32-time)
   - 3.3. [State](#33-state)
   - 3.4. [Stream-Table Duality](#34-stream-table-duality)
   - 3.5. [Time Windows](#35-time-windows)
   - 3.6. [Processing Guarantees](#36-processing-guarantees)
4. [Stream Processing Design Patterns](#4-stream-processing-design-patterns)
   - 4.1. [Single-Event Processing](#41-single-event-processing)
   - 4.2. [Processing with Local State](#42-processing-with-local-state)
   - 4.3. [Multiphase Processing/Repartitioning](#43-multiphase-processingrepartitioning)
   - 4.4. [Stream-Table Join](#44-stream-table-join)
   - 4.5. [Table-Table Join](#45-table-table-join)
   - 4.6. [Streaming Join](#46-streaming-join)
   - 4.7. [Out-of-Sequence Events](#47-out-of-sequence-events)
   - 4.8. [Reprocessing](#48-reprocessing)
   - 4.9. [Interactive Queries](#49-interactive-queries)
5. [Kafka Streams by Example](#5-kafka-streams-by-example)
   - 5.1. [Word Count](#51-word-count)
   - 5.2. [Stock Market Statistics](#52-stock-market-statistics)
   - 5.3. [ClickStream Enrichment](#53-clickstream-enrichment)
6. [Kafka Streams: Architecture Overview](#6-kafka-streams-architecture-overview)
   - 6.1. [Building a Topology](#61-building-a-topology)
   - 6.2. [Optimizing a Topology](#62-optimizing-a-topology)
   - 6.3. [Testing a Topology](#63-testing-a-topology)
   - 6.4. [Scaling a Topology](#64-scaling-a-topology)
   - 6.5. [Surviving Failures](#65-surviving-failures)
7. [Stream Processing Use Cases](#7-stream-processing-use-cases)
   - 7.1. [Customer Service](#71-customer-service)
   - 7.2. [Internet of Things](#72-internet-of-things)
   - 7.3. [Fraud Detection](#73-fraud-detection)
8. [How to Choose a Stream Processing Framework](#8-how-to-choose-a-stream-processing-framework)
   - 8.1. [Application Types](#81-application-types)
   - 8.2. [Global Considerations](#82-global-considerations)
9. [Summary](#9-summary)

---

## 1. Introduction

Kafka was traditionally seen as a powerful message bus, capable of delivering streams of events but without processing or transformation capabilities. For years, systems like Apache Storm, Apache Spark Streaming, Apache Flink, and Apache Samza were built specifically to process data from Kafka.

**In plain English:** Think of early Kafka like a postal service that only delivered packages but couldn't open them or sort them. You needed separate companies to process the contents.

**The turning point:** Starting from version 0.10.0, Kafka included a powerful stream processing library called **Kafka Streams** as part of its client libraries. Now developers can consume, process, and produce events in their own apps without relying on external frameworks.

> **💡 Insight**
>
> Stream processing was held back by the same problem that made databases revolutionary: without a reliable platform for storing and accessing data streams, every application had to solve the same infrastructure problems repeatedly. Kafka became that platform—the "database for streams."

### 1.1. Recommended Reading

This chapter provides a quick introduction to stream processing and Kafka Streams. For deeper exploration:

**Conceptual books:**
- *Making Sense of Stream Processing* by Martin Kleppmann (O'Reilly)
- *Streaming Systems* by Tyler Akidau, Slava Chernyak, and Reuven Lax (O'Reilly)
- *Flow Architectures* by James Urquhart (O'Reilly)

**Framework-specific books:**
- *Mastering Kafka Streams and ksqlDB* by Mitch Seymour (O'Reilly)
- *Kafka Streams in Action* by William P. Bejeck Jr. (Manning)
- *Event Streaming with Kafka Streams and ksqlDB* by William P. Bejeck Jr. (Manning)

**Important note:** This chapter documents Apache Kafka 2.8. Kafka Streams is an evolving framework—APIs and semantics change with major releases.

---

## 2. What Is Stream Processing?

### 2.1. Understanding Data Streams

**In plain English:** A data stream is like a never-ending river—water keeps flowing, you can observe it continuously, but you can never see "all" the water at once because more is always coming.

**In technical terms:** A data stream (or event stream) is an abstraction representing an **unbounded dataset**. Unbounded means infinite and ever-growing—new records continuously arrive over time.

**Examples of event streams:**
- Credit card transactions
- Stock trades
- Package deliveries
- Network events through a switch
- Sensor data from manufacturing equipment
- Emails sent
- Game player moves

> **💡 Insight**
>
> Almost every business activity can be modeled as a sequence of events. This mental shift—from "current state" to "stream of changes"—is fundamental to modern data architecture.

### 2.2. Stream Attributes

Beyond being unbounded, event streams have three critical attributes:

#### Ordered Events

**In plain English:** The sequence matters. "Deposit $100, then spend $50" is completely different from "Spend $50, then deposit $100"—the first is fine, the second incurs overdraft charges.

**Key difference from databases:** Database table records are unordered. The SQL `ORDER BY` clause was added for reporting, not as part of the relational model.

#### Immutable Data Records

**In plain English:** Events are historical facts that can't be changed. If a transaction is canceled, you don't delete the original—you record a new "cancellation" event.

**Example flow:**
```
Event 1: Customer bought merchandise
Event 2: Customer returned merchandise

Database table: Shows no purchase (deleted)
Event stream: Shows both purchase and return (complete history)
```

**Key difference from databases:** Database tables allow updates and deletes. These operations themselves are events that could be captured in a stream (binlog, WAL, redo log).

#### Replayable Streams

**In plain English:** You can go back in time and watch the same events again—like rewinding a video.

**Why this matters:**
- Correct errors in processing logic
- Try new analysis methods
- Perform audits
- Test new features on real historical data

> **💡 Insight**
>
> Kafka's replayability made stream processing practical for businesses. Without the ability to replay months or years of historical events, stream processing would be limited to lab experiments. This capability transformed it into a production-ready platform.

**Important notes:**
- Stream events can be tiny (few bytes) or large (XML with headers)
- Structure varies: unstructured key-value, semi-structured JSON, structured Avro/Protobuf
- Volume varies: few events per minute to millions per second
- Same techniques apply regardless of size or volume

### 2.3. Processing Paradigms Compared

Stream processing is one of three fundamental processing paradigms:

#### Request-Response

**In plain English:** Like asking someone a question and waiting for an immediate answer.

**Characteristics:**
- **Latency:** Submilliseconds to milliseconds
- **Mode:** Blocking (wait for response)
- **Examples:** Point-of-sale systems, credit card processing, time-tracking
- **Database equivalent:** OLTP (Online Transaction Processing)

#### Batch Processing

**In plain English:** Like doing all your laundry once a week instead of washing each shirt as you wear it.

**Characteristics:**
- **Latency:** Minutes to hours
- **Schedule:** Fixed times (every day at 2 AM, every hour)
- **Mode:** Process all available data, then stop
- **Examples:** Data warehouses, business intelligence, monthly reports
- **Database equivalent:** Data warehouse and BI systems

**The modern problem:** Businesses increasingly need faster insights. Waiting until tomorrow's batch job isn't fast enough for competitive decision-making.

#### Stream Processing

**In plain English:** Like a factory assembly line—continuously processing items as they arrive, never stopping, but not requiring instant millisecond responses either.

**Characteristics:**
- **Latency:** Seconds to minutes
- **Mode:** Continuous and nonblocking
- **Examples:** Real-time fraud detection, dynamic pricing, package tracking

**The sweet spot:**
```
Request-Response: "I need an answer RIGHT NOW" (milliseconds)
Stream Processing: "Keep me continuously updated" (seconds)
Batch Processing: "Tell me tomorrow" (hours/days)
```

> **💡 Insight**
>
> Stream processing fills a critical gap: most business processes don't need millisecond responses (too expensive) but can't wait for daily batches (too slow). Continuous processing at human timescales (seconds/minutes) matches how business actually operates.

**Critical requirement:** Processing must be continuous and ongoing. A process that runs once per day, processes 500 records, and exits is batch processing—not stream processing.

---

## 3. Stream Processing Concepts

Stream processing shares similarities with traditional data processing but introduces unique concepts that often confuse newcomers. Let's examine these key concepts.

### 3.1. Topology

**In plain English:** A topology is like a factory assembly line diagram—it shows all the workstations (processing steps) and how products (events) flow between them from raw materials (input) to finished goods (output).

**In technical terms:** A topology (also called DAG—directed acyclic graph) is a set of operations and transitions that events move through from input to output.

**Visual representation:**
```
Source Topics              Processing Steps              Sink Topics
─────────────              ────────────────              ───────────
Topic A ──→ Filter ──→ Transform ──→ Aggregate ──→ Result Topic
Topic B ──→ Map ──────→ Group By ──→ Count ────→ Stats Topic
```

**Components:**
- **Source processors:** Consume data from topics
- **Stream processors:** Transform data (filter, map, aggregate, join)
- **Sink processors:** Produce results to topics

**Example processors:**
- Filter (remove unwanted events)
- Count (aggregate totals)
- Group-by (organize by key)
- Left-join (enrich with additional data)

> **💡 Insight**
>
> Visualizing topologies as graphs helps debug and optimize stream applications. Complex processing becomes easier to understand when you can see the data flow visually—just like network diagrams or database query plans.

### 3.2. Time

**In plain English:** "What time is it?" seems simple until you realize different systems have different clocks, messages can be delayed, and the time an event happened might differ from when you learned about it.

**Why time is critical:** Most stream operations use time windows—"calculate the five-minute moving average of stock prices." But what happens when a producer goes offline for two hours and returns with old data?

> **💡 Insight**
>
> Time in distributed systems is profoundly complex. For deep exploration, read Justin Sheehy's paper "There Is No Now." The fundamental problem: in distributed systems, there's no single "now"—only different perspectives of when things happened.

#### Three Notions of Time

**Event Time**

**In plain English:** When the event actually happened in the real world.

**Definition:** The time the tracked event occurred—measurement taken, item sold, page viewed.

**In Kafka:** Since version 0.10.0, Kafka automatically adds timestamps to producer records. If this doesn't match your event time (e.g., records created from database entries), add event time as a field in the record.

**When to use:** Almost always. You care about when things happened, not when you heard about them.

**Example:** Counting devices produced per day—you want devices actually produced that day, even if network issues delayed the event until the next day.

**Log Append Time**

**In plain English:** When Kafka received and stored the event.

**Definition:** The time the event arrived at the Kafka broker (also called ingestion time).

**In Kafka:** Brokers automatically add this timestamp if configured or if records come from older producers.

**When to use:** When real event time wasn't recorded and you need consistent timestamps. Can approximate event time if pipeline delays are minimal.

**Processing Time**

**In plain English:** When your application happened to read the event.

**Definition:** The time at which the stream processing application received the event.

**Problems:**
- Same event gets different timestamps in different applications
- Different threads in the same application assign different times
- Highly unreliable and inconsistent

**When to use:** Avoid if possible. Highly unreliable.

#### Time in Kafka Streams

**Timestamp extraction:** Kafka Streams uses the `TimestampExtractor` interface. Developers can choose:
- Event time (recommended)
- Log append time
- Processing time
- Custom extraction from event contents

**Output timestamps:** When Kafka Streams writes results:

```
Input → Output mapping: Same timestamp
Aggregation result: Maximum timestamp from aggregated events
Join result: Largest timestamp from joined records
Stream-table join: Timestamp from stream record
Scheduled generation (punctuate): Internal stream app time
```

> **💡 Insight**
>
> Time zone standardization is critical. The entire pipeline should use a single time zone (typically UTC). If handling multiple time zones, store the time zone in each record to enable conversion before window operations.

### 3.3. State

**In plain English:** State is like memory—information you need to remember from previous events to process current events correctly.

#### Simple Processing (Stateless)

**Example:** Read shopping transactions, find those over $10,000, email the salesperson.

```
Event → Check if > $10,000 → Send email (if yes)
```

This requires no state—each event is processed independently.

#### Complex Processing (Stateful)

**In plain English:** State becomes necessary when processing requires information from multiple events—counting, averaging, joining, or any operation that says "based on what I've seen so far..."

**Examples requiring state:**
- Count events by type this hour
- Calculate moving averages
- Join two streams
- Track sums, averages, minimums, maximums

**The naive approach:**
```java
// DON'T DO THIS - State lost on restart!
Map<String, Integer> counts = new HashMap<>();
```

**The problem:** When the application stops or crashes, state disappears. Results change incorrectly.

#### Types of State

**Local (Internal) State**

**In plain English:** Like keeping a notepad at your desk—fast to access but limited to your workspace.

**Characteristics:**
- Accessible only by specific application instance
- Maintained in embedded, in-memory database
- **Advantage:** Extremely fast
- **Disadvantage:** Limited by available memory

**Design pattern:** Partition data into substreams that fit in memory.

**External State**

**In plain English:** Like using a shared filing cabinet—everyone can access it, unlimited storage, but slower to retrieve.

**Characteristics:**
- Maintained in external data store (Cassandra, Redis, etc.)
- Accessible from multiple instances/applications
- **Advantages:** Virtually unlimited size, shared access
- **Disadvantages:** Added latency, complexity, availability concerns

**Best practice:** Most stream apps avoid external stores or cache aggressively in local state, syncing minimally with external storage.

> **💡 Insight**
>
> State management is what separates trivial stream processing from production-ready systems. Kafka Streams excels here—it persists local state to Kafka topics, enabling fast recovery after failures while maintaining the speed of in-memory processing.

### 3.4. Stream-Table Duality

**In plain English:** Streams and tables are two ways of looking at the same information—like how a bank statement (stream of transactions) and account balance (table with current amount) represent the same money.

#### Understanding Tables

**Characteristics:**
- Collection of records identified by primary key
- Contains current state at a specific point in time
- Records are mutable (allow updates and deletes)

**Example:** `CUSTOMERS_CONTACTS` table shows current contact details, not historical changes.

#### Understanding Streams

**Characteristics:**
- History of changes over time
- Each event represents a change
- Immutable (events can't be changed)

**Example:** Stream of all customer contact updates ever made.

#### The Duality

```
TABLE ←→ STREAM

Current State ←→ History of Changes

One view      ←→ Different view
Same reality       Same reality
```

> **💡 Insight**
>
> Systems that seamlessly convert between streams and tables are more powerful than those supporting only one. This duality enables both real-time processing (stream view) and point-in-time queries (table view) on the same data.

#### Table → Stream (Capture Changes)

**Method:** Change Data Capture (CDC)

**Process:**
1. Capture all insert, update, delete operations
2. Store these changes as events in a stream
3. Stream now contains complete modification history

**In Kafka:** Many Kafka Connect connectors perform CDC, piping database changes into Kafka topics.

#### Stream → Table (Materialize View)

**Method:** Apply all changes

**Process:**
1. Create a table (in memory, state store, or external database)
2. Read events from stream beginning to end
3. Apply each change to the table
4. Result: Current state at a specific time

**Example: Shoe Store**

**Stream representation:**
```
Event 1: Shipment arrived (300 red, 300 blue, 300 green shoes)
Event 2: Blue shoes sold (-1 blue)
Event 3: Red shoes sold (-1 red)
Event 4: Blue shoes returned (+1 blue)
Event 5: Green shoes sold (-1 green)
```

**Materialized table:**
```
Inventory Status (Now):
- Red shoes: 299
- Blue shoes: 300
- Green shoes: 299
```

**Stream view:** Shows 4 customer events today, reveals why blue shoes were returned

**Table view:** Shows current inventory—299 red shoes available now

### 3.5. Time Windows

**In plain English:** Windows are like looking at data through a moving frame—"show me the average for the last 5 minutes" requires defining what "last 5 minutes" means as time moves forward.

**Why windows matter:** Most stream operations are windowed—moving averages, top products this week, 99th percentile load, joins of two streams.

#### Window Parameters

When calculating windows, you must define:

**1. Window Size**

**Question:** How much time does each window cover?

**Examples:**
- 5-minute windows
- 15-minute windows
- Full day

**Trade-off:**
```
Large windows: Smoother results, Slower to detect changes
Small windows: Faster detection, Noisier results
```

**Special case:** **Session windows** size is defined by inactivity periods. All events with gaps smaller than the session gap belong to one session. A larger gap starts a new session.

**2. Advance Interval**

**In plain English:** How often does the window update?

**Question:** How frequently do we recalculate?

**Examples for 5-minute window:**
- Update every minute
- Update every second
- Update on every new event

**Window types:**
- **Hopping window:** Advance interval is a fixed time
- **Tumbling window:** Advance interval equals window size (no overlap)

**3. Grace Period**

**In plain English:** How long do we accept late-arriving data?

**Question:** Our 00:00–00:05 window closed. An hour later, events with timestamp 00:02 arrive. Do we update the result or ignore them?

**Example policy:**
- Accept events delayed up to 4 hours (recalculate and update)
- Ignore events arriving later than 4 hours

#### Window Alignment

**Aligned to clock time:**
```
First window:  00:00–00:05
Second window: 00:01–00:06
Third window:  00:02–00:07
```

**Unaligned (application start time):**
```
App started at 03:17
First window:  03:17–03:22
Second window: 03:18–03:23
```

**Visual comparison:**
```
Tumbling Window (5 minutes, non-overlapping):
[00:00-00:05] [00:05-00:10] [00:10-00:15]
     ↓             ↓             ↓
   Events      Events        Events
   grouped     grouped       grouped

Hopping Window (5 minutes, advance 1 minute):
[00:00-00:05]
  [00:01-00:06]
    [00:02-00:07]
      [00:03-00:08]
        ↓
    Overlapping windows
    Same events in multiple windows
```

> **💡 Insight**
>
> Window configuration dramatically affects results. A 5-minute tumbling window produces very different insights than a 5-minute hopping window that advances every second. Choose based on your latency requirements and how much data smoothing you need.

### 3.6. Processing Guarantees

**In plain English:** Exactly-once processing means every event affects the result exactly one time—not zero times (data loss), not two times (double-counting), but precisely once.

**Why it matters:** Without exactly-once guarantees, stream processing can't be used where accurate results are critical (financial calculations, inventory counts, billing).

#### Kafka's Exactly-Once Semantics

**Foundation:** Transactional and idempotent producer (detailed in Chapter 8)

**In Kafka Streams:** Uses Kafka transactions to implement exactly-once guarantees

**Configuration:**
```java
// Enable exactly-once (requires Kafka 0.11+)
props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, "exactly_once");

// More efficient version (requires Kafka 2.5+, Kafka Streams 2.6+)
props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, "exactly_once_beta");
```

> **💡 Insight**
>
> Exactly-once semantics was once considered impossible in distributed systems—a "holy grail" of stream processing. Kafka's implementation using transactions and idempotence proves it's achievable with the right architecture. This capability separates production-grade stream processing from academic experiments.

---

## 4. Stream Processing Design Patterns

Stream processing systems vary widely—from simple consumer-process-producer combinations to sophisticated clusters like Spark Streaming. Despite this diversity, common design patterns solve recurring architectural challenges.

### 4.1. Single-Event Processing

**In plain English:** The simplest pattern—look at each event independently, do something with it, and move on. Like an assembly line worker who examines each item and either passes it along or sets it aside.

**Also known as:** Map/filter pattern

**Characteristics:**
- Process each event in isolation
- No state required between events
- Easy recovery and load balancing

**Example 1: Filter by priority**
```
Input Stream:  [ERROR log, INFO log, DEBUG log, ERROR log]
                    ↓
               Filter (keep only ERROR)
                    ↓
Output Streams: High-priority: [ERROR log, ERROR log]
                Low-priority: [INFO log, DEBUG log]
```

**Example 2: Transform format**
```
Input:  JSON events
   ↓
Convert JSON to Avro
   ↓
Output: Avro events
```

**Simple implementation:**
```
Consumer → Process → Producer
   ↓          ↓         ↓
 Read     Transform   Write
```

**Visual topology:**
```
Source Topic → Map/Filter → Sink Topic
```

> **💡 Insight**
>
> Stateless processing is the easiest to scale and maintain. When events are independent, failures are simple to handle—just restart processing on another instance. If your use case allows stateless processing, prefer it over stateful alternatives.

### 4.2. Processing with Local State

**In plain English:** Like keeping a running tally at your workstation—you track totals, minimums, or averages for your assigned work, but you don't need to know about everyone else's numbers.

**Common use case:** Window aggregations—calculate minimum, maximum, moving averages per group.

**Example: Stock price statistics**

**Task:** Calculate daily minimum price and moving average per stock symbol

**Required state:**
- Minimum value seen today
- Sum of all prices
- Count of price records

**Key insight: Partitioning enables local state**

```
Stock Events by Symbol:
IBM events → Partition 0 → Instance A (tracks IBM state)
AAPL events → Partition 1 → Instance B (tracks AAPL state)
GOOG events → Partition 2 → Instance A (tracks GOOG state)
```

**How partitioning works:**
1. Kafka partitioner sends all events with same key (stock symbol) to same partition
2. Each application instance gets assigned specific partitions
3. Each instance maintains state only for its partitions

**Visual topology:**
```
Input Topic (partitioned by stock symbol)
       ↓
   Group By Key
       ↓
   Window (5 min)
       ↓
   Aggregate
   (Local State Store)
       ↓
Output Topic (aggregated results)
```

#### Challenges with Local State

**1. Memory Usage**

**Problem:** Local state must fit in available memory

**Solutions:**
- Partition data into smaller subsets
- Use local stores that spill to disk (with performance cost)

**2. Persistence**

**Problem:** State must survive application restarts

**Solutions:**
- Embed RocksDB for persistent local storage
- Replicate state changes to Kafka topics
- Use log compaction to prevent infinite topic growth

**Kafka Streams approach:**
```
Local State Store (RocksDB)
       ↓
   Persisted to disk
       ↓
   Changes sent to Kafka topic (changelog)
       ↓
   Can recreate state by replaying changelog
```

**3. Rebalancing**

**Problem:** Partition reassignment requires state migration

**Process:**
1. Instance losing partition stores current state
2. Instance receiving partition recovers correct state
3. Processing continues seamlessly

> **💡 Insight**
>
> Local state management is where stream processing frameworks differ dramatically. Some handle persistence, recovery, and rebalancing automatically. Others expose "leaky abstractions" requiring manual state management. Kafka Streams excels by making local state automatic and reliable.

### 4.3. Multiphase Processing/Repartitioning

**In plain English:** Sometimes you need to process data in multiple stages, where each stage needs the data organized differently—like sorting mail first by state, then by city, then by street.

**When needed:** Operations requiring all data, not just local subsets

**Example: Top 10 stocks**

**Task:** Find the 10 stocks with the largest daily gains

**Problem:** Local processing isn't enough—top 10 stocks could be spread across all partitions on different instances.

**Solution: Two-phase approach**

**Phase 1: Local aggregation**
```
Calculate daily gain/loss per stock symbol
(Each instance handles its assigned stock symbols)

Partition 0: IBM (+5%), MSFT (+2%)
Partition 1: AAPL (+7%), GOOG (+3%)
Partition 2: AMZN (+4%), TSLA (+9%)
```

**Phase 2: Global aggregation**
```
Write all results to topic with single partition
↓
Single instance reads entire result set
↓
Calculate top 10 across all stocks
```

**Visual topology:**
```
Input Topic (trades, many partitions)
       ↓
  Local State Aggregate
  (Calculate daily stats per stock)
       ↓
Intermediate Topic (daily stats, many partitions)
       ↓
  Repartition to 1 partition
       ↓
   Global Aggregate
   (Find top 10)
       ↓
Output Topic (top 10 stocks)
```

**Key insight:** Intermediate topic has much less data
- Input: Millions of trades per day
- Intermediate: One summary per stock per day
- Single partition can handle summary volume

> **💡 Insight**
>
> Multiphase processing resembles MapReduce—multiple reduce steps chained together. Unlike MapReduce (separate apps per step), stream frameworks run all phases in a single application topology. The framework handles which instances run which steps.

### 4.4. Stream-Table Join

**In plain English:** Enriching stream events with reference data is like a factory worker looking up part specifications in a manual—you need fast access to relatively stable information to enhance each passing item.

**Use case:** Enrich stream events with external data (user profiles, product catalogs, validation rules)

**Example: Enrich clickstream**

**Naive approach (Don't do this!):**
```
For each click event:
   ↓
Query user profile database
   ↓
Combine click + profile data
   ↓
Write enriched event
```

**Problems:**
- 5-15ms latency per database query
- Stream processing handles 100K–500K events/sec
- Database can only handle ~10K queries/sec
- Availability issues when database is down

**Better approach: Cache with CDC**

**Step 1: Capture database changes**
```
User Profile Database
       ↓
Change Data Capture (CDC connector)
       ↓
Stream of profile updates
```

**Step 2: Maintain local table**
```
Stream Processing Application
       ↓
Maintains local copy of user profiles
       ↓
Updates when database changes arrive
```

**Step 3: Join stream with local table**
```
Click events → Look up user in local cache → Enriched events
              (Fast, local, no database calls)
```

**Visual topology:**
```
Profile Changes Stream → Local User Table
                              ↑
Click Events Stream ──────────┘
                              ↓
                    Stream-Table Join
                              ↓
                    Enriched Events
```

**Benefits:**
- **Performance:** Local lookups are microseconds, not milliseconds
- **Scalability:** No database load
- **Availability:** Works even if database is offline
- **Freshness:** Updates arrive as database changes

> **💡 Insight**
>
> Stream-table joins implement a powerful pattern: maintaining a local, eventually-consistent cache of reference data. This is the stream processing equivalent of dimension tables in data warehousing—slowly-changing reference data that enriches fast-moving fact data.

### 4.5. Table-Table Join

**In plain English:** Sometimes both sides of a join represent current state that changes over time—like maintaining an up-to-date view that combines your customer list with their current order status.

**Key difference from stream-table join:** Both sides are materialized views of change streams

**Characteristics:**
- **Non-windowed:** Always joins current state at time of operation
- **Equi-join:** Both tables use same key, partitioned identically
- **Distributed:** Join operation efficiently distributed across instances

**Example:**
```
Customer Table (from customer changes stream)
       ⊕
Order Status Table (from order changes stream)
       ↓
Current Customer-Order View
```

**Advanced capability: Foreign-key join**

Kafka Streams supports joining on arbitrary fields, not just partition keys:
- Stream/table key joins with field from another stream/table
- More complex but more flexible

**Learn more:**
- "Crossing the Streams" talk (Kafka Summit 2020)
- Foreign-key join blog post

> **💡 Insight**
>
> Table-table joins blur the line between stream processing and traditional databases. You're maintaining materialized views that update continuously—like a database view that refreshes in real time instead of on-demand.

### 4.6. Streaming Join

**In plain English:** Joining two real event streams is like matching up related activities that happen close together in time—connecting search queries with the results users clicked on moments later.

**Key characteristic:** Windowed join—match events that occurred within the same time window

**Example: Search to click attribution**

**Scenario:**
- Stream 1: Search queries users entered
- Stream 2: Clicks on search results

**Goal:** Match searches with relevant clicks (those occurring shortly after)

**Implementation:**
```
Search Stream:  [Query A at 10:00:01]
                        ↓
                 Keep in window
                        ↓
Click Stream:   [Click B at 10:00:03] ← Within 1 second?
                        ↓
                      Yes!
                        ↓
                Join: Query A + Click B
```

**Visual topology:**
```
Search Stream → Buffer (1-second window)
                        ⊕
Click Stream  → Buffer (1-second window)
                        ↓
                  Join on user_id
                        ↓
              Attributed Clicks
```

**Window configuration:**
```java
// 1 second window after search (not before)
JoinWindows.of(Duration.ofSeconds(1))
           .before(Duration.ofSeconds(0))
```

**How Kafka Streams implements it:**

1. **Partition alignment:** Both streams partitioned on user_id
   ```
   Search partition 5: user_id:42 searches
   Click partition 5: user_id:42 clicks
   ```

2. **Co-location:** Same task processes both partition 5s

3. **Local state:** Task maintains join windows for both streams in RocksDB

4. **Join execution:** All events for user_id:42 available in one place

> **💡 Insight**
>
> Stream-to-stream joins are unique to stream processing—traditional databases can't do this efficiently. The key insight: maintain sliding time windows in local state, joining events as they arrive within the window. This enables real-time correlation analysis impossible with batch processing.

### 4.7. Out-of-Sequence Events

**In plain English:** Events sometimes arrive late—like mail that gets lost in the post office and shows up weeks later. Your system needs to decide: do we process this late event, or is it too old to care about?

**Common scenarios:**
- Mobile devices reconnect after hours offline, send backlog of events
- Network equipment sends diagnostics after repair
- Manufacturing sensors in areas with unreliable connectivity

**Example:**
```
Current processing time: 15:00
Event arrives with timestamp: 12:00
↓
3 hours late!
```

**Visual representation:**
```
Expected Timeline:
12:00 ──→ 13:00 ──→ 14:00 ──→ 15:00 (Now)

Actual Arrival:
Event from 12:00 ────────────────→ Arrives at 15:00
                                   ↑
                            Out of sequence!
```

#### Handling Requirements

**1. Recognize out-of-sequence events**

Compare event time with current processing time:
```
if (event_time < current_processing_time - threshold)
   → Out of sequence
```

**2. Define reconciliation period**

**Example policy:**
```
Accept delays: Up to 3 hours (reconcile)
Reject delays: Over 3 weeks (discard)
```

**3. In-band reconciliation**

**Key difference from batch processing:**
```
Batch job: Rerun yesterday's job to update
Stream processing: Same continuous process handles both old and new events
```

**4. Update results**

**Different targets require different strategies:**
```
Database results: Simple PUT/UPDATE
Email results: Harder to update (can't unsend)
```

#### Framework Support

**Kafka Streams capabilities:**
- Event time tracking independent of processing time
- Multiple aggregation windows kept available for updates
- Configurable window update duration
- Automatic result updates via compacted topics

**Window update example:**
```
Window 00:00–00:05 calculated and written
↓
Late event arrives with timestamp 00:02
↓
Recalculate window 00:00–00:05
↓
Write new result (replaces old result via log compaction)
```

> **💡 Insight**
>
> Out-of-sequence handling separates toy systems from production-ready ones. Real-world networks are unreliable, devices go offline, and clock skew exists. Frameworks with built-in late-event handling (grace periods, window updates) enable building robust systems without custom bookkeeping.

### 4.8. Reprocessing

**In plain English:** Reprocessing is like having a "do-over" button—run your improved algorithm on the same historical events to generate better results.

#### Two Reprocessing Variants

**Variant 1: A/B Testing (Safe approach)**

**Scenario:** Improved version of application—test before fully switching

**Process:**
1. Run new version alongside old version
2. Both process same input stream
3. Both produce separate output streams
4. Compare results
5. Switch clients to new results when ready

**Visual flow:**
```
                    ┌→ App v1 (consumer group: v1) → Results v1
Input Stream ───────┤
                    └→ App v2 (consumer group: v2) → Results v2
                              ↓
                    Compare and validate
                              ↓
                    Switch clients to v2
```

**Variant 2: Fix Bugs (Riskier approach)**

**Scenario:** Existing app is buggy—fix and recalculate

**Process:**
1. Fix bug in application
2. Reset application state
3. Reprocess from beginning
4. Overwrite previous results

**Visual flow:**
```
Buggy app produced wrong results
↓
Stop app, reset state
↓
Start fixed app from beginning offset
↓
Reprocess all events
↓
Produce corrected results
```

#### Implementation in Kafka Streams

**Variant 1 (Recommended):**
```
1. Deploy new version with new consumer group ID
2. Configure to start from earliest offset
3. Let it process entire history
4. Monitor both result streams
5. Switch clients when caught up
```

**Variant 2:**
```
# Use Kafka Streams reset tool
kafka-streams-application-reset --application-id my-app

Caution: Risk of data loss if cleanup goes wrong
```

**Recommendation:** Prefer Variant 1 when capacity allows
- Safer (can rollback)
- Allows result comparison
- No risk of losing critical data
- More validation opportunities

> **💡 Insight**
>
> Kafka's retention of complete event streams makes reprocessing practical. Unlike systems where historical data is deleted after processing, Kafka lets you "time travel"—reprocess months or years of events to fix bugs or test improvements. This capability transforms stream processing from a fragile pipeline to a robust, testable system.

### 4.9. Interactive Queries

**In plain English:** Sometimes instead of reading results from output topics, you want to directly ask the stream processing application for the current state—like checking a scoreboard instead of watching every point being scored.

**Use case:** When result is a table (top 10 books, current inventory), not a continuous stream

**Example:**
```
Stream of sales events
       ↓
   Aggregate into "Top 10 Books"
       ↓
Instead of: Reading changelog stream of top-10 updates
Use this: Query current top-10 directly from app state
```

**Benefits:**
- **Faster:** Read directly from memory instead of Kafka
- **Simpler:** No need to maintain separate consumer
- **Current:** Always up-to-date with latest calculation

**Kafka Streams support:**
Flexible APIs for querying stream processing application state stores

> **💡 Insight**
>
> Interactive queries turn stream processing applications into queryable databases. The application maintains materialized views in local state, and you can query them directly—combining the benefits of stream processing (continuous updates) with database-style queries (point-in-time reads).

---

## 5. Kafka Streams by Example

Now let's see these patterns in action with concrete Kafka Streams implementations. We'll use the **Kafka Streams DSL** (Domain-Specific Language)—a high-level API for defining stream transformations.

> **Note:** Kafka Streams also provides a lower-level Processor API for custom transformations. See the developer guide and "Beyond the DSL" presentation for details.

### 5.1. Word Count

**Pattern demonstrated:** Single-event processing, map/filter, simple aggregation

**Full example:** [GitHub - Word Count](https://github.com/apache/kafka)

#### Step 1: Configuration

Every Kafka Streams application needs basic configuration:

```java
public class WordCountExample {
    public static void main(String[] args) throws Exception {
        Properties props = new Properties();

        // Must be unique per application
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "wordcount");

        // Where to find Kafka
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

        // How to serialize/deserialize
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG,
                  Serdes.String().getClass().getName());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG,
                  Serdes.String().getClass().getName());
```

**Configuration explained:**

**APPLICATION_ID_CONFIG:**
- Coordinates multiple instances
- Names internal local stores and topics
- Must be unique per application

**BOOTSTRAP_SERVERS_CONFIG:**
- Kafka cluster connection
- Used for reading, writing, and coordination

**SERDE configs:**
- Default serializer/deserializer classes
- Can override per operation if needed

#### Step 2: Build Topology

Define the transformation pipeline:

```java
StreamsBuilder builder = new StreamsBuilder();

// Read from input topic
KStream<String, String> source =
    builder.stream("wordcount-input");

// Define word splitting pattern
final Pattern pattern = Pattern.compile("\\W+");

// Build transformation pipeline
KStream<String, String> counts = source
    // Split lines into words
    .flatMapValues(value ->
        Arrays.asList(pattern.split(value.toLowerCase())))

    // Move word to key (for grouping)
    .map((key, value) -> new KeyValue<>(value, value))

    // Filter out common word
    .filter((key, value) -> (!value.equals("the")))

    // Group by word (key)
    .groupByKey()

    // Count occurrences
    .count()

    // Convert count to String for readability
    .mapValues(value -> Long.toString(value))

    // Convert table back to stream
    .toStream();

// Write results to output topic
counts.to("wordcount-output");
```

**Pipeline breakdown:**

```
Input: "The quick brown fox"
       ↓
flatMapValues: ["the", "quick", "brown", "fox"]
       ↓
map: [("the","the"), ("quick","quick"), ("brown","brown"), ("fox","fox")]
       ↓
filter: [("quick","quick"), ("brown","brown"), ("fox","fox")]  // "the" removed
       ↓
groupByKey: Groups by word
       ↓
count: {"quick":1, "brown":1, "fox":1}
       ↓
mapValues: {"quick":"1", "brown":"1", "fox":"1"}
       ↓
Output: Stream of word counts
```

#### Step 3: Run Application

Create and start the Kafka Streams execution object:

```java
        // Create execution object
        KafkaStreams streams = new KafkaStreams(builder.build(), props);

        // Start processing
        streams.start();

        // Run for a while (normally runs forever)
        Thread.sleep(5000L);

        // Clean shutdown
        streams.close();
    }
}
```

**Execution flow:**
1. `KafkaStreams` object created from topology and properties
2. `start()` begins processing threads
3. Threads continuously process events
4. `close()` shuts down gracefully

#### Running the Example

**Local development:**
```bash
# No installation needed except Kafka!
# Run from terminal

# If input topic has multiple partitions:
# Open multiple terminals, run same app
# → Automatic cluster with work coordination
```

**Key insight: No cluster installation needed**

Traditional frameworks require:
- Install YARN or Mesos
- Deploy framework to cluster
- Learn cluster submission process

Kafka Streams approach:
- Start multiple instances of your app
- Automatic coordination via Kafka
- Same app runs locally and in production

> **💡 Insight**
>
> Kafka Streams removes the traditional barrier between development and production. Your local development setup is identical to production—just JAR files running as applications. This dramatically simplifies deployment and testing.

### 5.2. Stock Market Statistics

**Pattern demonstrated:** Windowed aggregation with local state

**Full example:** [GitHub - Stock Stats](https://github.com/apache/kafka)

**Goal:** Calculate windowed statistics on stock trades
- Minimum ask price per 5-second window
- Number of trades per 5-second window
- Average ask price per 5-second window
- Update every second

**Input data:**
- Stock ticker symbol
- Ask price (seller's asking price)
- Ask size (shares offered)
- Timestamp (event time from producer)

#### Configuration

Similar to word count, but with custom Serde:

```java
Properties props = new Properties();
props.put(StreamsConfig.APPLICATION_ID_CONFIG, "stockstat");
props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, Constants.BROKER);
props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG,
          Serdes.String().getClass().getName());
props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG,
          TradeSerde.class.getName());  // Custom Serde for Trade objects
```

**Creating custom Serde with Gson:**

```java
static public final class TradeSerde extends WrapperSerde<Trade> {
    public TradeSerde() {
        super(new JsonSerializer<Trade>(),
              new JsonDeserializer<Trade>(Trade.class));
    }
}
```

**Key principle:** Provide Serde for every object type
- Input objects
- Output objects
- Intermediate results
- Use libraries (Gson, Avro, Protobuf) to generate Serdes

#### Building the Topology

```java
KStream<Windowed<String>, TradeStats> stats = source
    // Ensure data partitioned by key (ticker symbol)
    .groupByKey()

    // Define time windows
    .windowedBy(TimeWindows.of(Duration.ofMillis(windowSize))
                           .advanceBy(Duration.ofSeconds(1)))

    // Aggregate events in each window
    .aggregate(
        // Initialize result object
        () -> new TradeStats(),

        // Update result with each event
        (k, v, tradestats) -> tradestats.add(v),

        // Configure state store
        Materialized.<String, TradeStats, WindowStore<Bytes, byte[]>>
            as("trade-aggregates")
            .withValueSerde(new TradeStatsSerde()))

    // Convert table back to stream
    .toStream()

    // Calculate average price from sum and count
    .mapValues((trade) -> trade.computeAvgPrice());

// Write results with windowed Serde
stats.to("stockstats-output",
    Produced.keySerde(
        WindowedSerdes.timeWindowedSerdeFrom(String.class, windowSize)));
```

**Topology breakdown:**

**groupByKey():**
- Despite the name, doesn't group—ensures correct partitioning
- Data already partitioned by key (ticker symbol)
- Validates partition alignment

**windowedBy():**
- Creates 5-second windows
- Advances every 1 second
- Results in overlapping windows

**aggregate():**

*Parameter 1: Initializer*
```java
() -> new TradeStats()
// Creates empty statistics object for each window
```

*Parameter 2: Aggregator*
```java
(k, v, tradestats) -> tradestats.add(v)
// Updates statistics with each new trade
// Tracks: minimum price, total price, trade count
```

*Parameter 3: Materialized (State Store Configuration)*
```java
Materialized.as("trade-aggregates")
            .withValueSerde(new TradeStatsSerde())
// Names the state store: "trade-aggregates"
// Provides Serde for serializing TradeStats objects
```

**State store management:**
- Automatically persisted to disk
- Changes replicated to Kafka topic
- Recovers automatically after failures

**mapValues():**
```java
.mapValues((trade) -> trade.computeAvgPrice())
// Calculate average = sum / count
// Add to output record
```

**Windowed output:**
```java
WindowedSerdes.timeWindowedSerdeFrom(String.class, windowSize)
// Serializes with window timestamp
// Includes window start time in output
```

#### What Makes This Work

**Automatic state management:**
- Local RocksDB store created automatically
- Changelog topic created in Kafka
- Recovery happens transparently
- Scales to multiple instances
- Rebalances on failures

> **💡 Insight**
>
> Windowed aggregation is the most common stream processing pattern. Kafka Streams makes it remarkably simple—just define the window, provide an aggregation function, and name the state store. The framework handles all the complexity: persistence, recovery, scaling, and rebalancing.

### 5.3. ClickStream Enrichment

**Pattern demonstrated:** Stream-table join and stream-stream join

**Full example:** [GitHub - ClickStream](https://github.com/apache/kafka)

**Goal:** Create 360-degree view of user activity by joining:
- Stream of page views (clicks)
- Stream of searches
- Stream of profile updates (from database CDC)

**Result:** Rich analytics dataset showing:
- What users searched for
- What they clicked
- Their profile interests
- Correlated user behavior

**Use case:** Product recommendations based on combined data

#### Configuration

Same pattern as previous examples:

```java
Properties props = new Properties();
props.put(StreamsConfig.APPLICATION_ID_CONFIG, "clickstream");
props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, Constants.BROKER);
// ... additional configuration
```

#### Building the Topology

**Step 1: Define inputs**

```java
// Stream of page views
KStream<Integer, PageView> views =
    builder.stream(Constants.PAGE_VIEW_TOPIC,
        Consumed.with(Serdes.Integer(), new PageViewSerde()));

// Stream of searches
KStream<Integer, Search> searches =
    builder.stream(Constants.SEARCH_TOPIC,
        Consumed.with(Serdes.Integer(), new SearchSerde()));

// Table of user profiles (materialized from change stream)
KTable<Integer, UserProfile> profiles =
    builder.table(Constants.USER_PROFILE_TOPIC,
        Consumed.with(Serdes.Integer(), new ProfileSerde()));
```

**Key difference:**
```
KStream: Unbounded stream of events
KTable: Materialized view, updated by change stream
```

**Step 2: Join stream with table (enrich clicks with profiles)**

```java
KStream<Integer, UserActivity> viewsWithProfile = views.leftJoin(
    profiles,  // Join with profiles table

    // Join function: combine page view + profile
    (page, profile) -> {
        if (profile != null)
            return new UserActivity(
                profile.getUserID(),
                profile.getUserName(),
                profile.getZipcode(),
                profile.getInterests(),
                "",              // Search terms (added later)
                page.getPage()); // Page viewed
        else
            return new UserActivity(-1, "", "", null, "", page.getPage());
    });
```

**How stream-table join works:**
```
Click event arrives with user_id: 42
       ↓
Look up user_id 42 in local profile cache
       ↓
Combine: Click data + Profile data
       ↓
Output: Enriched activity record
```

**Join method explained:**
- Takes two parameters: stream event, table record
- Returns combined result
- Developer controls how to merge data

**Step 3: Join enriched stream with search stream**

```java
KStream<Integer, UserActivity> userActivityKStream =
    viewsWithProfile.leftJoin(
        searches,  // Join with searches stream

        // Join function: add search terms to activity
        (userActivity, search) -> {
            if (search != null)
                userActivity.updateSearch(search.getSearchTerms());
            else
                userActivity.updateSearch("");
            return userActivity;
        },

        // Window: match searches and clicks within 1 second
        JoinWindows.of(Duration.ofSeconds(1))
                   .before(Duration.ofSeconds(0)),

        // Serdes for all three types
        StreamJoined.with(
            Serdes.Integer(),      // Key Serde (user_id)
            new UserActivitySerde(), // Left stream Serde
            new SearchSerde()));     // Right stream Serde
```

**Stream-to-stream join characteristics:**

**Requires time window:**
```
Search event at 10:00:01
       ↓
Keep in 1-second window
       ↓
Click event at 10:00:01.5 ← Within window?
       ↓
Yes! Join them
```

**Window configuration:**
```java
JoinWindows.of(Duration.ofSeconds(1))  // 1 second total
           .before(Duration.ofSeconds(0))  // Only after search (not before)

Result: Clicks within 1 second AFTER search are joined
```

**Why window matters:**
```
Without window: All searches joined with all clicks (meaningless)
With window: Only related clicks joined with their search (meaningful)
```

**Serde requirements:**
```java
StreamJoined.with(
    Serdes.Integer(),          // Key (user_id) present in both streams
    new UserActivitySerde(),   // Value from left stream
    new SearchSerde())         // Value from right stream
```

#### Complete Data Flow

```
Profile Change Stream → Local Profile Table
                              ↑
Page View Stream ─────────────┴─→ Stream-Table Join
                                        ↓
                                  Enriched Views
                                        ↓
                              ┌─────────┴──────────┐
                              ↓                    ↓
                        Search Stream       Enriched Views
                              └──→ Stream-Stream Join
                                        ↓
                              Complete User Activity
                     (Profile + Page View + Search Terms)
```

> **💡 Insight**
>
> This example demonstrates the power of joining streams and tables. The stream-table join (clicks + profiles) is like a database fact-dimension join but continuous. The stream-stream join (clicks + searches) with time windows is unique to stream processing—correlating events that happen close together in time.

---

## 6. Kafka Streams: Architecture Overview

Now that we've seen what Kafka Streams can do, let's understand how it works under the hood.

### 6.1. Building a Topology

**In plain English:** A topology is the complete blueprint of your stream processing application—all the steps and how they connect, from reading input to writing output.

**Visual representation (Word Count example):**

```
Source                Transform              Aggregate           Sink
──────                ─────────              ─────────           ────

wordcount-input ──→ flatMapValues ──→ map ──→ filter ──→ groupByKey
                                                              ↓
                                                           count
                                                              ↓
                                                         mapValues
                                                              ↓
                                                      wordcount-output
```

**Components:**

**Processors (nodes in the graph):**
- Source processors: Read from topics
- Stream processors: Transform data (filter, map, aggregate)
- Sink processors: Write to topics

**Streams (edges in the graph):**
- Connect processors
- Flow of events from one step to next

> **💡 Insight**
>
> Visualizing topologies as graphs helps debug and optimize. Complex applications become clearer when you can see data flow—similar to database query execution plans or network topology diagrams.

### 6.2. Optimizing a Topology

**The three-step execution process:**

```
Step 1: Define logical topology
        (Create KStream/KTable, call DSL methods)
              ↓
Step 2: Generate physical topology
        (StreamsBuilder.build() applies optimizations)
              ↓
Step 3: Execute topology
        (KafkaStreams.start() begins processing)
```

**Where optimization happens:** Step 2—converting logical to physical topology

**Current optimizations:**
- Reuse topics where possible
- Eliminate redundant operations
- Combine compatible steps

**Enabling optimization:**

```java
// Method 1: Pass config to build()
props.put(StreamsConfig.TOPOLOGY_OPTIMIZATION, StreamsConfig.OPTIMIZE);
builder.build(props);

// Method 2: build() without config (no optimization)
builder.build();  // Optimization disabled
```

**Recommendation:**
- Test with and without optimization
- Compare execution times
- Compare data volumes written to Kafka
- Validate results are identical
- Choose based on performance/correctness trade-off

> **💡 Insight**
>
> Topology optimization is similar to database query optimization—the framework analyzes your logical plan and generates an efficient physical plan. The separation between logical definition and physical execution enables these optimizations without changing your code.

### 6.3. Testing a Topology

**In plain English:** Test your stream processing app like any software—automated tests that run quickly and catch bugs before production.

#### Testing Approaches

**Unit/Integration Tests: TopologyTestDriver**

**What it does:**
- Runs topology with mock topics
- Processes test input data
- Captures output for validation
- Fast, lightweight, easy to debug

**Example test structure:**

```java
// 1. Define test input
TestInputTopic<String, String> inputTopic = ...;

// 2. Send test data
inputTopic.pipeInput("key1", "test data");

// 3. Run topology
TopologyTestDriver testDriver = new TopologyTestDriver(topology, props);

// 4. Read results
TestOutputTopic<String, Long> outputTopic = ...;
KeyValue<String, Long> result = outputTopic.readKeyValue();

// 5. Validate
assertEquals(expectedValue, result.value);
```

**Limitations:**
- Doesn't simulate Kafka Streams caching behavior
- Some optimization-related bugs won't be detected
- Need additional integration tests

**Integration Tests: EmbeddedKafkaCluster vs. Testcontainers**

**EmbeddedKafkaCluster:**
- Runs Kafka brokers inside JVM
- Faster startup
- Shared resources with test

**Testcontainers (Recommended):**
- Runs Kafka in Docker containers
- Full isolation
- Better resembles production
- More accurate resource usage

**Further reading:** "Testing Kafka Streams—A Deep Dive" blog post

> **💡 Insight**
>
> Testing stream processing applications was historically difficult—requiring full Kafka clusters for even simple tests. TopologyTestDriver and Testcontainers make it practical to test thoroughly, catching bugs before production deployment.

### 6.4. Scaling a Topology

**In plain English:** Kafka Streams scales by running multiple copies of your application—either multiple threads in one process or multiple processes on different servers. Work is automatically distributed among them.

#### The Task Model

**Tasks are the unit of parallelism**

**How task count is determined:**
```
Number of tasks = Number of input topic partitions
```

**Task responsibility:**
- Subscribe to assigned partitions
- Consume events from those partitions
- Execute all processing steps for those events
- Write results to output topics

**Example with 4 partitions:**

```
Input Topic (4 partitions)
├── Partition 0 → Task 0
├── Partition 1 → Task 1
├── Partition 2 → Task 2
└── Partition 3 → Task 3

Each task runs the same topology on its partitions
```

#### Scaling Patterns

**Single machine, multiple threads:**

```java
props.put(StreamsConfig.NUM_STREAM_THREADS_CONFIG, 4);

Application Instance
├── Thread 1 → Task 0
├── Thread 2 → Task 1
├── Thread 3 → Task 2
└── Thread 4 → Task 3
```

**Multiple machines:**

```
Server 1: Instance A
  ├── Thread 1 → Task 0
  └── Thread 2 → Task 1

Server 2: Instance B
  ├── Thread 1 → Task 2
  └── Thread 2 → Task 3
```

**Key insight: Automatic coordination**
- Kafka coordinates task assignment
- Each task gets unique partitions
- Each task maintains independent local state
- No shared memory or resources

#### Handling Dependencies

**Problem:** Some operations need data from multiple partitions (joins)

**Example: Join two streams**
```
Click Stream (Partition 0) ─┐
                             ├─→ Must be in same task!
Search Stream (Partition 0) ─┘
```

**Solution:** Co-location

Kafka Streams assigns all partitions needed for a join to the same task:
```
Task 0:
├── Clicks Partition 0
└── Searches Partition 0
    ↓
Can perform join locally
```

**Requirement:** Topics in join must have:
- Same number of partitions
- Same partition key
- Aligned partitioning strategy

#### Scaling Through Repartitioning

**Problem:** Need to group data by different key

**Example:**
```
Events partitioned by user_id
But we need statistics by zip_code
```

**Solution: Repartitioning creates new subtopology**

```
Subtopology 1 (partitioned by user_id):
Input Topic → Process by user → Intermediate Topic
                                (partitioned by zip_code)
                                       ↓
Subtopology 2 (partitioned by zip_code):
Intermediate Topic → Process by zip_code → Output Topic
```

**Visual representation:**

```
Tasks 0-3 (process by user_id)
       ↓
  Write to intermediate topic
  (repartitioned by zip_code)
       ↓
Tasks 4-7 (process by zip_code)
```

**Benefits of repartitioning via topics:**
- No direct communication between task sets
- No shared resources
- Can run independently
- Can run on different servers
- Natural backpressure (topic buffering)

> **💡 Insight**
>
> Kafka's use of topics for repartitioning is brilliant—it turns complex inter-task communication into simple producer/consumer operations. This eliminates the tight coupling and coordination overhead common in other stream processing frameworks.

### 6.5. Surviving Failures

**In plain English:** Kafka Streams applications recover from failures automatically—if a server crashes, its work shifts to remaining servers seamlessly.

#### Recovery Mechanisms

**1. Kafka's High Availability**

**Data persistence:**
```
Application fails
       ↓
Last position stored in Kafka
       ↓
Restart application
       ↓
Resume from last committed offset
```

**State recovery:**
```
Local state store lost
       ↓
Changelog topic still in Kafka
       ↓
Replay changelog to rebuild state
```

**2. Task Rebalancing**

**Failure scenario:**
```
Instance A (Tasks 0, 1) ← Crashes!
Instance B (Tasks 2, 3)
       ↓
Rebalance
       ↓
Instance B (Tasks 0, 1, 2, 3) ← Takes over all tasks
```

**Similar to consumer groups:**
- Failed consumer partitions reassigned
- Failed task reassigned to active thread
- Automatic and transparent

**3. Advanced Features**

**Kafka Streams benefits from:**
- Static group membership (faster rebalancing)
- Cooperative rebalancing (no stop-the-world)
- Exactly-once semantics (no duplicate processing)

#### The Recovery Time Challenge

**Problem:** State recovery can be slow

**Typical recovery process:**
```
Task fails on Server A
       ↓
Assigned to Server B
       ↓
Server B must rebuild state
       ↓
Read changelog from Kafka (slow!)
       ↓
During recovery: No progress on that data subset
       ↓
Results become stale
```

**Solutions:**

**1. Aggressive Compaction**

```java
// Changelog topic configuration
min.compaction.lag.ms = 100  // Compact quickly
segment.ms = 100            // Smaller segments
segment.bytes = 104857600   // 100 MB instead of 1 GB
```

**Why this helps:**
- Smaller changelog to replay
- Faster state recovery
- Less downtime

**2. Standby Replicas**

**Configuration:**
```java
props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 1);
```

**How it works:**
```
Active Task (Server A)
       ↓
   Processing events
       ↓
Standby Task (Server B) ← Keeps state warm
       ↓
Server A fails
       ↓
Standby on Server B promotes to active (nearly instant!)
```

**Benefits:**
- Near-zero downtime
- State already current
- Minimal recovery time

**Trade-off:**
- Uses more resources (duplicate state storage)
- Worth it for critical applications

**Further reading:**
- "Kafka Streams Scalability" blog post
- "High Availability in Kafka Streams" Kafka Summit talk

> **💡 Insight**
>
> Kafka Streams' failure handling demonstrates the power of persisting state to Kafka. Other frameworks struggle with state recovery because they don't have a durable, replicated changelog. Kafka Streams treats state as another stream—making recovery just another consumption operation.

---

## 7. Stream Processing Use Cases

Now that we understand how to do stream processing, let's examine real-world scenarios where it provides unique value.

### 7.1. Customer Service

**The problem scenario:**

**Bad experience (batch processing):**
```
Customer books hotel reservation
       ↓
Call customer service 5 minutes later
       ↓
"I don't see your reservation. Our system updates once per day.
Please call back tomorrow. Email arrives in 2-3 business days."
```

**This really happens!** Large hotel chains have this exact problem.

**The stream processing solution:**

```
Customer books reservation
       ↓ (seconds)
Reservation event published to Kafka
       ↓
Multiple systems consume in real-time:
├─→ Customer service desk (immediate access)
├─→ Hotel front desk (sees booking)
├─→ Email service (sends confirmation in minutes)
├─→ Website (shows in "My Reservations")
├─→ Loyalty program (recognizes customer)
└─→ Billing system (charges card)
```

**Benefits:**
- Email confirmation within minutes
- Customer service can immediately answer questions
- Hotel knows about reservation before guest arrives
- All systems see customer loyalty status
- Coordinated, consistent experience

> **💡 Insight**
>
> Stream processing transforms customer experience by eliminating the artificial delays of batch processing. When every system receives updates within seconds, customers see one unified organization instead of disconnected departments.

### 7.2. Internet of Things

**In plain English:** IoT generates massive streams of sensor data—stream processing detects patterns that signal problems before they cause failures.

**Common IoT use cases:**

**Predictive Maintenance**

**Goal:** Predict when equipment needs maintenance before it fails

**Industries:**
- Manufacturing (machinery sensors)
- Telecommunications (cellphone towers)
- Cable TV (set-top boxes)
- Transportation (vehicle fleet monitoring)

**Example: Manufacturing**

```
Sensor Events Stream:
├─→ Motor temperature trending higher
├─→ Vibration frequency changing
├─→ More force needed to tighten screws
└─→ Pattern match: Likely failure within 24 hours
       ↓
Alert maintenance team
       ↓
Preventive service before breakdown
```

**Example: Telecommunications**

```
Cell Tower Events:
├─→ Increased dropped packets
├─→ Signal strength degrading
├─→ More connection retries
└─→ Pattern match: Tower hardware issue
       ↓
Dispatch technician
       ↓
Fix before customer complaints
```

**Key capability:** Process events at large scale, identify patterns signaling problems

### 7.3. Fraud Detection

**Also known as:** Anomaly detection

**Goal:** Catch bad actors in real-time before damage occurs

**Application areas:**
- Credit card fraud
- Stock trading fraud
- Video game cheaters
- Cybersecurity threats

**Why stream processing matters:**

```
Batch detection (daily job):
Fraud happens Monday → Detected Thursday → Cleanup difficult

Stream detection:
Fraud happens Monday 10:00 → Detected 10:00:05 → Transaction blocked
```

**Example: Credit Card Fraud**

```
Transaction Events Stream:
├─→ $50 purchase at local grocery (normal)
├─→ $10,000 purchase in another country (3 minutes later)
└─→ Pattern match: Impossible travel time + unusual amount
       ↓
Block transaction immediately
       ↓
Alert customer
```

**Example: Cybersecurity (Beaconing)**

**The threat:**
```
Hacker plants malware inside organization
       ↓
Malware periodically "phones home" for commands
       ↓
Can happen at any time/frequency
       ↓
Hard to detect in batch processing
```

**Stream processing detection:**
```
Network Connection Events:
├─→ Internal host connecting to external IP
├─→ Pattern match: Unusual destination for this host
├─→ Pattern match: Periodic timing (beaconing signature)
└─→ Alert security team immediately
       ↓
Investigate and contain before more damage
```

**Key insight:** Organizations have good defenses against external attacks but are vulnerable to internal hosts reaching out. Stream processing detects abnormal communication patterns in real-time.

> **💡 Insight**
>
> Fraud detection demonstrates stream processing's unique value: some patterns only emerge by correlating events in real-time across large data volumes. Batch processing is too slow, and simple rules miss sophisticated attacks. Stream processing enables complex pattern detection at the speed of business.

---

## 8. How to Choose a Stream Processing Framework

Not all stream processing solutions fit all problems. Let's examine how to match frameworks to use cases.

### 8.1. Application Types

Different application types have different requirements:

#### Ingest

**Goal:** Move data from one system to another with transformations

**Characteristics:**
- Source and destination systems clearly defined
- Simple transformations (format conversion, filtering)
- Reliability more important than complex processing

**Recommendation:** **Consider Kafka Connect first**

Kafka Connect is purpose-built for ingest:
- Large connector ecosystem
- Exactly-once delivery
- Scalable and reliable
- Simpler than full stream processing

**When to use stream processing:**
- Complex transformations required
- Multiple data sources combined
- Stateful processing needed

**If using stream processing, prioritize:**
- Quality connector ecosystem
- Connector reliability and performance

#### Low-Millisecond Actions

**Goal:** Near-instant response to events (sub-second latency)

**Examples:**
- Real-time fraud blocking (milliseconds to decide)
- High-frequency trading responses
- Instant security threat blocking

**Recommendation:** **Reconsider request-response pattern**

Request-response often better for ultra-low latency:
- Optimized for immediate responses
- Simpler architecture
- More predictable performance

**If using stream processing, prioritize:**
- Event-by-event processing model (not microbatches)
- Low-latency architecture
- Minimal processing overhead

**Avoid:**
- Frameworks focused on microbatching (Spark Streaming)
- Heavy processing frameworks
- Complex windowing for simple operations

#### Asynchronous Microservices

**Goal:** Microservice performs specific task in larger workflow

**Examples:**
- Update inventory after purchase
- Send notification after account creation
- Update search index after content change

**Characteristics:**
- Simple, focused responsibility
- Maintains local state (cache/materialized view)
- Needs change data capture

**Framework requirements:**
- Excellent Kafka integration
- CDC capabilities (database change streams)
- Strong local state store support
- Fast local cache/materialized view

#### Near Real-Time Data Analytics

**Goal:** Complex aggregations and joins for business insights

**Examples:**
- Multi-stream correlation analysis
- Complex windowed aggregations
- Real-time dashboards
- Pattern detection across data sources

**Characteristics:**
- Advanced operations (joins, aggregations, windows)
- Multiple data sources
- Continuous result updates

**Framework requirements:**
- Robust local state store (for aggregations)
- Custom aggregation support
- Multiple window operation types
- Various join types (stream-stream, stream-table, table-table)
- Windowing flexibility

### 8.2. Global Considerations

Beyond use case–specific requirements, evaluate these universal factors:

#### Operability

**Questions to ask:**
- How easy is production deployment?
- What monitoring tools are available?
- How do you troubleshoot issues?
- How does it scale up/down?
- What if you need to reprocess data?
- Does it integrate with existing infrastructure?

**Why it matters:**
```
Development time: 20% of total cost
Operations time: 80% of total cost

Easy to deploy + Hard to operate = Expensive disaster
```

**Evaluation checklist:**
- Deployment complexity
- Monitoring/observability tools
- Scaling procedures
- Reprocessing capabilities
- Infrastructure integration
- Operational documentation

#### Usability and Debugging

**In plain English:** Development time varies wildly between frameworks—orders of magnitude difference for the same functionality.

**Impact on business:**
- Time to market
- Developer productivity
- Bug fix speed
- Feature iteration rate

**Questions to ask:**
- How long to write a high-quality application?
- How easy is debugging?
- How clear are error messages?
- How good is documentation?
- How steep is learning curve?

**Compare:**
```
Framework A: Basic aggregation takes 500 lines, 2 weeks
Framework B: Same aggregation takes 50 lines, 2 days

10x productivity difference!
```

#### Clean APIs and Abstractions

**In plain English:** Does the framework handle complexity for you, or do you handle it yourself?

**Key distinction:**

**Good abstraction:**
```
kafkaStreams.aggregate()
// Framework handles:
// - State persistence
// - Recovery after failures
// - Scaling across instances
// - Rebalancing partitions
```

**Leaky abstraction:**
```
framework.aggregate()
// You must manually handle:
// - State store configuration
// - Failure recovery logic
// - Scaling coordination
// - Rebalancing procedures
```

**Questions to ask:**
- Do advanced features require understanding internals?
- Does the framework handle scale automatically?
- Does the framework handle recovery automatically?
- How much boilerplate code is required?

**Warning signs:**
- "You just need to configure X, Y, and Z for state persistence"
- "For recovery, implement these 3 interfaces"
- "To scale, manually partition your data first"

#### Community

**Why community matters:**

**Active community provides:**
- Regular new features
- High-quality code (many eyes on it)
- Fast bug fixes
- Answered questions (Stack Overflow, forums)
- Shared solutions to common problems
- Production experience (battle-tested)

**Evaluation metrics:**
- GitHub activity (commits, PRs, releases)
- Stack Overflow questions/answers
- Conference presentations
- Blog posts and tutorials
- Commercial support availability
- Company adoption (who uses it in production)

**Red flags:**
- Last release over a year ago
- Unanswered GitHub issues
- No Stack Overflow activity
- No conference presence

> **💡 Insight**
>
> Framework choice is a long-term commitment—you'll live with it for years. Optimize for total cost of ownership (development + operations) over the application lifetime, not just initial development time. A framework that takes slightly longer to learn but is easier to operate will save money and headaches over years of production use.

---

## 9. Summary

**What we learned:**

**1. Stream Processing Fundamentals**

Stream processing is continuous processing of unbounded datasets:
- Fills the gap between instant request-response and slow batch processing
- Processes events as they arrive (seconds/minutes latency)
- Enables real-time business insights and actions

**2. Key Concepts**

**Data streams:**
- Unbounded (continuously growing)
- Ordered (sequence matters)
- Immutable (events are historical facts)
- Replayable (can reprocess historical data)

**Time:**
- Event time (when it happened)
- Log append time (when Kafka received it)
- Processing time (when app processed it)

**State:**
- Local state (fast, memory-limited)
- External state (unlimited, slower)
- Kafka Streams automatically persists and recovers state

**Topologies:**
- Directed graph of processing steps
- Source → Processors → Sink
- Can be optimized and tested

**3. Design Patterns**

**Single-event processing:** Stateless map/filter operations

**Local state:** Windowed aggregations partitioned by key

**Multiphase processing:** Repartitioning for different groupings

**Stream-table join:** Enrich events with reference data

**Stream-stream join:** Correlate events in time windows

**Out-of-sequence events:** Handle late arrivals with grace periods

**Reprocessing:** Replay historical data with improved logic

**4. Kafka Streams Architecture**

**Scaling model:**
- Tasks assigned to partitions
- Multiple threads and instances
- Automatic coordination via Kafka

**Failure handling:**
- State persisted to Kafka changelogs
- Automatic recovery after failures
- Optional standby replicas for fast failover

**Testing:**
- Unit tests with TopologyTestDriver
- Integration tests with Testcontainers

**5. Real-World Use Cases**

**Customer service:** Real-time system updates improve experience

**IoT:** Predictive maintenance from sensor patterns

**Fraud detection:** Real-time anomaly detection prevents damage

**6. Choosing a Framework**

Match framework to use case:
- Ingest → Consider Kafka Connect
- Low latency → Consider request-response
- Microservices → Need strong local state support
- Analytics → Need advanced aggregations and joins

Evaluate globally:
- Operability (deployment, monitoring, scaling)
- Usability (development time, debugging)
- Abstractions (framework handles complexity)
- Community (active development, support)

**Key takeaway:** Stream processing transforms how businesses handle data—from delayed batch insights to continuous real-time intelligence. Kafka Streams makes this accessible by integrating stream processing into the same platform that stores and transports events, creating a unified architecture for event-driven applications.

---

**Previous:** [Chapter 13: Monitoring Kafka](./chapter13.md) | **Next:** (none - this is the final chapter)
