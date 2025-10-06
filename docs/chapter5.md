# 5. Managing Apache Kafka Programmatically

> **In plain English:** AdminClient is like a remote control for Kafka - it lets your applications create topics, check configurations, manage consumer groups, and perform other administrative tasks without using command-line tools.
>
> **In technical terms:** Apache Kafka's AdminClient provides a programmatic API for administrative operations that were previously only available via CLI tools or direct ZooKeeper manipulation.
>
> **Why it matters:** Applications can dynamically adapt to changing requirements - creating topics on demand, validating configurations, managing consumer groups, and recovering from failures - all without manual intervention or external tooling.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [AdminClient Overview](#2-adminclient-overview)
   - 2.1. [Design Principles](#21-design-principles)
   - 2.2. [Creating and Configuring](#22-creating-and-configuring)
3. [Topic Management](#3-topic-management)
   - 3.1. [Listing Topics](#31-listing-topics)
   - 3.2. [Describing Topics](#32-describing-topics)
   - 3.3. [Creating Topics](#33-creating-topics)
   - 3.4. [Deleting Topics](#34-deleting-topics)
4. [Configuration Management](#4-configuration-management)
   - 4.1. [Reading Configurations](#41-reading-configurations)
   - 4.2. [Modifying Configurations](#42-modifying-configurations)
5. [Consumer Group Management](#5-consumer-group-management)
   - 5.1. [Listing Consumer Groups](#51-listing-consumer-groups)
   - 5.2. [Describing Consumer Groups](#52-describing-consumer-groups)
   - 5.3. [Checking Consumer Lag](#53-checking-consumer-lag)
   - 5.4. [Modifying Consumer Offsets](#54-modifying-consumer-offsets)
6. [Advanced Operations](#6-advanced-operations)
   - 6.1. [Adding Partitions](#61-adding-partitions)
   - 6.2. [Deleting Records](#62-deleting-records)
   - 6.3. [Leader Election](#63-leader-election)
   - 6.4. [Reassigning Replicas](#64-reassigning-replicas)
7. [Working with Futures](#7-working-with-futures)
8. [Testing with MockAdminClient](#8-testing-with-mockadminclient)
9. [Summary](#9-summary)

---

## 1. Introduction

Before AdminClient existed, administrative tasks required either command-line tools or direct ZooKeeper manipulation. This created challenges for application developers.

**The old world (before AdminClient):**

```
Need to create a topic?
├─ Option 1: Tell users to run kafka-topics.sh
│           └─> Manual step, error-prone
├─ Option 2: Hope auto.create.topics.enable = true
│           └─> Unreliable, not always enabled
└─ Option 3: Use internal APIs
            └─> No compatibility guarantees, breaks between versions
```

**The new world (with AdminClient):**

```
Need to create a topic?
└─> Check if exists, create if not, validate configuration
    All programmatically, all in your application code
```

**Common use cases:**

1. **IoT applications**: Create topic per device type on-demand
2. **Multi-tenant systems**: Create topic per tenant automatically
3. **Application startup**: Validate required topics exist with correct configuration
4. **SRE tooling**: Build custom automation and recovery scripts
5. **Monitoring**: Check consumer lag, detect slow consumers

---

## 2. AdminClient Overview

### 2.1. Design Principles

#### Asynchronous and Eventually Consistent

**In plain English:** AdminClient sends requests and returns immediately with a Future. The actual work happens asynchronously, and Kafka's internal state takes time to propagate.

```
Timeline:
0ms:   createTopics() returns immediately → Future returned
       ↓
10ms:  Request reaches controller
       ↓
50ms:  Controller updates its state → Future completes
       ↓
100ms: Some brokers know about new topic
       ↓
500ms: All brokers know about new topic
```

**Eventual consistency implications:**

```
admin.createTopics(["new-topic"])
      .all().get(); // Wait for Future to complete

// At this moment:
// - Controller knows about topic ✓
// - Some brokers know about topic (maybe)
// - All brokers know about topic (eventually)

admin.listTopics() // Might not include "new-topic" yet!
```

> **💡 Insight**
>
> This is similar to DNS propagation - when you create a new domain, it takes time for all DNS servers worldwide to learn about it. Similarly, when you create a topic, it takes time for all Kafka brokers to learn about it.

#### Options Objects

**Every method accepts an Options object:**

```java
// All methods follow this pattern:
admin.listTopics(options);
admin.createTopics(topics, options);
admin.describeCluster(options);
```

**Common options:**

```java
ListTopicsOptions options = new ListTopicsOptions()
    .timeoutMs(30000)           // Wait up to 30 seconds
    .listInternal(true);        // Include internal topics

DescribeClusterOptions options = new DescribeClusterOptions()
    .timeoutMs(60000)
    .includeAuthorizedOperations(true); // Show what client can do
```

#### Flat Hierarchy

**Everything in one class:**

```java
KafkaAdminClient admin = ...;

admin.listTopics();           // Topic operations
admin.describeConsumerGroups(); // Consumer group operations
admin.describeConfigs();      // Configuration operations
admin.describeCluster();      // Cluster operations
admin.electLeaders();         // Advanced operations

// No admin.topics().list()
// No admin.consumerGroups().describe()
// Everything is directly on AdminClient
```

**Benefit:** Easy discovery - one class, one JavaDoc to search

### 2.2. Creating and Configuring

**Basic creation:**

```java
Properties props = new Properties();
props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");

AdminClient admin = AdminClient.create(props);

// ... use admin ...

admin.close(Duration.ofSeconds(30)); // Wait up to 30s for ongoing operations
```

**Important configurations:**

#### client.dns.lookup

**Scenario 1: DNS Alias for Bootstrap**

```
Problem:
├─ Brokers: broker1.example.com, broker2.example.com, broker3.example.com
├─ Create alias: kafka.example.com → All brokers
├─ Use SASL authentication
└─> SASL expects broker name but gets alias → Authentication fails!

Solution:
props.put("client.dns.lookup", "resolve_canonical_bootstrap_servers_only");

Result:
├─ Client resolves kafka.example.com → [broker1, broker2, broker3]
└─> Connects using actual broker names → Authentication succeeds ✓
```

**Scenario 2: Load Balancer with Multiple IPs**

```
Problem:
├─ broker1.example.com → [IP1, IP2, IP3] (all load balancers)
├─ Client tries only first IP
└─> If IP1 down, connection fails even though broker accessible!

Solution:
props.put("client.dns.lookup", "use_all_dns_ips");

Result:
├─ Client gets all IPs
├─> Tries IP1, if fails tries IP2, if fails tries IP3
└─> Connection succeeds as long as any load balancer works ✓
```

#### request.timeout.ms

```java
props.put("request.timeout.ms", "120000"); // 2 minutes (default)
```

**Why long timeout:**

```
Some operations are slow:
├─ Consumer group management: 30-60 seconds possible
├─ Creating many topics: Several seconds
└─> Better to wait than fail prematurely
```

---

## 3. Topic Management

### 3.1. Listing Topics

**Simple list:**

```java
ListTopicsResult topics = admin.listTopics();
topics.names().get().forEach(System.out::println);
```

**How it works:**

```
listTopics() returns immediately → ListTopicsResult
                ↓
topics.names() returns Future<Set<String>>
                ↓
.get() blocks until Future completes
                ↓
Set<String> returned → Iterate and print
```

### 3.2. Describing Topics

**Check if topic exists with correct configuration:**

```java
DescribeTopicsResult demoTopic = admin.describeTopics(
    Collections.singletonList("demo-topic"));

try {
    TopicDescription desc = demoTopic.values().get("demo-topic").get();

    System.out.println("Topic: " + desc.name());
    System.out.println("Partitions: " + desc.partitions().size());

    if (desc.partitions().size() != EXPECTED_PARTITIONS) {
        System.out.println("Wrong number of partitions!");
        System.exit(-1);
    }

} catch (ExecutionException e) {
    if (e.getCause() instanceof UnknownTopicOrPartitionException) {
        System.out.println("Topic doesn't exist");
    } else {
        throw e;
    }
}
```

**What TopicDescription contains:**

```
TopicDescription:
├─ name: "demo-topic"
├─ internal: false
├─ partitions: List<TopicPartitionInfo>
│   └─ For each partition:
│       ├─ partition: 0
│       ├─ leader: Broker 1
│       ├─ replicas: [Broker 1, Broker 2, Broker 3]
│       └─ isr: [Broker 1, Broker 2, Broker 3]
└─ authorizedOperations: [READ, WRITE, DELETE, ...]
```

> **💡 Insight**
>
> AdminClient result objects throw ExecutionException when Kafka returns an error. This is because they're wrapped Future objects. Always examine e.getCause() to get the actual Kafka error.

### 3.3. Creating Topics

**Create with all defaults:**

```java
NewTopic newTopic = new NewTopic("simple-topic", -1, (short) -1);
// -1 means use broker defaults for partitions and replicas

admin.createTopics(Collections.singletonList(newTopic)).all().get();
```

**Create with specific configuration:**

```java
NewTopic newTopic = new NewTopic(
    "demo-topic",      // name
    NUM_PARTITIONS,    // partitions
    REP_FACTOR);       // replication factor

CreateTopicsResult result = admin.createTopics(
    Collections.singletonList(newTopic));

// Validate result
if (result.numPartitions("demo-topic").get() != NUM_PARTITIONS) {
    System.out.println("Topic created with wrong number of partitions!");
    System.exit(-1);
}
```

**Complete example: Check and create if needed:**

```java
try {
    // Try to describe the topic
    TopicDescription desc = admin.describeTopics(
        Collections.singletonList(TOPIC_NAME))
        .values().get(TOPIC_NAME).get();

    // Topic exists, validate configuration
    if (desc.partitions().size() != NUM_PARTITIONS) {
        System.out.println("Topic has wrong number of partitions. Exiting.");
        System.exit(-1);
    }

    System.out.println("Topic exists with correct configuration");

} catch (ExecutionException e) {
    if (!(e.getCause() instanceof UnknownTopicOrPartitionException)) {
        e.printStackTrace();
        throw e;
    }

    // Topic doesn't exist, create it
    System.out.println("Topic doesn't exist. Creating...");

    NewTopic newTopic = new NewTopic(TOPIC_NAME, NUM_PARTITIONS, REP_FACTOR);
    CreateTopicsResult newTopicResult = admin.createTopics(
        Collections.singletonList(newTopic));

    // Validate creation
    if (newTopicResult.numPartitions(TOPIC_NAME).get() != NUM_PARTITIONS) {
        System.out.println("Topic created with wrong number of partitions.");
        System.exit(-1);
    }

    System.out.println("Topic created successfully");
}
```

### 3.4. Deleting Topics

```java
admin.deleteTopics(Collections.singletonList("demo-topic")).all().get();

// Verify deletion (may take time due to async nature)
try {
    admin.describeTopics(Collections.singletonList("demo-topic"))
        .values().get("demo-topic").get();
    System.out.println("Topic still exists");
} catch (ExecutionException e) {
    System.out.println("Topic deleted successfully");
}
```

**Critical warning:**

```
Deletion is FINAL:
├─ No recycle bin
├─ No "Are you sure?"
├─> Data is gone forever!

Best practices:
├─ Double-check topic name
├─ Require manual confirmation in tooling
└─> Consider backup/snapshot before deletion
```

---

## 4. Configuration Management

### 4.1. Reading Configurations

**Get topic configuration:**

```java
ConfigResource configResource = new ConfigResource(
    ConfigResource.Type.TOPIC,
    "demo-topic");

DescribeConfigsResult configsResult = admin.describeConfigs(
    Collections.singleton(configResource));

Config configs = configsResult.all().get().get(configResource);

// Print non-default configurations
configs.entries().stream()
    .filter(entry -> !entry.isDefault())
    .forEach(System.out::println);
```

**Configuration types:**

```
ConfigResource.Type:
├─ TOPIC: Topic configurations
├─ BROKER: Broker configurations
└─ BROKER_LOGGER: Broker logging levels
```

**What ConfigEntry contains:**

```
ConfigEntry:
├─ name: "cleanup.policy"
├─ value: "compact"
├─ isDefault: false
├─ isSensitive: false
├─ isReadOnly: false
└─ source: USER (or DEFAULT, DYNAMIC_BROKER_CONFIG, etc.)
```

### 4.2. Modifying Configurations

**Example: Ensure topic is compacted:**

```java
ConfigResource configResource = new ConfigResource(
    ConfigResource.Type.TOPIC,
    "demo-topic");

// Check current configuration
DescribeConfigsResult result = admin.describeConfigs(
    Collections.singleton(configResource));
Config configs = result.all().get().get(configResource);

// Check if topic is compacted
ConfigEntry compaction = new ConfigEntry(
    TopicConfig.CLEANUP_POLICY_CONFIG,
    TopicConfig.CLEANUP_POLICY_COMPACT);

if (!configs.entries().contains(compaction)) {
    // Topic not compacted, fix it
    System.out.println("Topic not compacted. Updating configuration...");

    Collection<AlterConfigOp> configOp = new ArrayList<>();
    configOp.add(new AlterConfigOp(compaction, AlterConfigOp.OpType.SET));

    Map<ConfigResource, Collection<AlterConfigOp>> alterConf = new HashMap<>();
    alterConf.put(configResource, configOp);

    admin.incrementalAlterConfigs(alterConf).all().get();

    System.out.println("Topic is now compacted");
} else {
    System.out.println("Topic is already compacted");
}
```

**Operation types:**

```
AlterConfigOp.OpType:
├─ SET: Set configuration value
│       └─> cleanup.policy = compact
├─ DELETE: Remove configuration (revert to default)
│       └─> cleanup.policy = [default]
├─ APPEND: Add to list configuration
│       └─> compression.type = [existing, snappy]
└─ SUBTRACT: Remove from list configuration
        └─> compression.type = [existing - gzip]
```

**Real-world scenario:**

```
Incident: Broker configuration file accidentally replaced
Problem: Broker won't start with broken config
Solution:
├─ Connect to another broker
├─> admin.describeConfigs() to dump configuration
└─> Reconstruct correct configuration file
```

> **💡 Insight**
>
> Being able to describe and modify configurations programmatically is incredibly powerful during emergencies. Build tools ahead of time - don't wait until 3 AM when production is down!

---

## 5. Consumer Group Management

### 5.1. Listing Consumer Groups

```java
admin.listConsumerGroups().valid().get().forEach(System.out::println);
```

**Understanding result methods:**

```
listConsumerGroups() returns ListConsumerGroupsResult

.valid():   Return only successful results (ignore errors)
.errors():  Return only errors
.all():     Return first error or all successful results
```

**Why errors occur:**

```
Possible errors:
├─ Authorization: Client lacks permission
├─> Coordinator unavailable: Broker down
└─> Network issues: Timeout
```

### 5.2. Describing Consumer Groups

```java
ConsumerGroupDescription groupDesc = admin
    .describeConsumerGroups(Collections.singletonList("my-group"))
    .describedGroups().get("my-group").get();

System.out.println("Group: " + groupDesc.groupId());
System.out.println("State: " + groupDesc.state());
System.out.println("Coordinator: " + groupDesc.coordinator());
System.out.println("Partition assignment strategy: " +
    groupDesc.partitionAssignor());

System.out.println("Members:");
for (MemberDescription member : groupDesc.members()) {
    System.out.println("  Member ID: " + member.consumerId());
    System.out.println("  Client ID: " + member.clientId());
    System.out.println("  Host: " + member.host());
    System.out.println("  Assigned partitions: " + member.assignment());
}
```

**What ConsumerGroupDescription contains:**

```
ConsumerGroupDescription:
├─ groupId: "my-consumer-group"
├─ state: STABLE (or PREPARING_REBALANCE, COMPLETING_REBALANCE, DEAD, EMPTY)
├─ coordinator: Broker(id=2, host=kafka2.example.com:9092)
├─ partitionAssignor: "range"
├─ members: List<MemberDescription>
│   └─ For each member:
│       ├─ consumerId: "consumer-1-a1b2c3d4"
│       ├─ clientId: "consumer-1"
│       ├─ host: "/192.168.1.10"
│       └─ assignment: {topic1-0, topic1-1, topic2-0}
└─ authorizedOperations: [READ, DELETE, ...]
```

### 5.3. Checking Consumer Lag

**Complete example:**

```java
// Step 1: Get committed offsets for the consumer group
Map<TopicPartition, OffsetAndMetadata> offsets = admin
    .listConsumerGroupOffsets("my-consumer-group")
    .partitionsToOffsetAndMetadata().get();

// Step 2: Prepare request for latest offsets in those partitions
Map<TopicPartition, OffsetSpec> requestLatestOffsets = new HashMap<>();
for (TopicPartition tp : offsets.keySet()) {
    requestLatestOffsets.put(tp, OffsetSpec.latest());
}

// Step 3: Get latest offsets
Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> latestOffsets =
    admin.listOffsets(requestLatestOffsets).all().get();

// Step 4: Calculate and print lag for each partition
for (Map.Entry<TopicPartition, OffsetAndMetadata> e : offsets.entrySet()) {
    String topic = e.getKey().topic();
    int partition = e.getKey().partition();
    long committedOffset = e.getValue().offset();
    long latestOffset = latestOffsets.get(e.getKey()).offset();
    long lag = latestOffset - committedOffset;

    System.out.printf("Topic: %s, Partition: %d, " +
                      "Committed: %d, Latest: %d, Lag: %d%n",
                      topic, partition, committedOffset, latestOffset, lag);
}
```

**Visual representation:**

```
Partition timeline:
[0][1][2][3][4][5][6][7][8][9]
            ↑               ↑
      Committed: 3    Latest: 9

Lag = 9 - 3 = 6 messages behind
```

**OffsetSpec options:**

```java
OffsetSpec.earliest()              // First offset in partition
OffsetSpec.latest()                // Last offset in partition
OffsetSpec.forTimestamp(timestamp) // Offset at/after timestamp
```

### 5.4. Modifying Consumer Offsets

**Use case: Reset consumer to beginning of topic**

**Important warnings:**

```
Before modifying offsets:
1. Stop the consumer group
   ├─> If group active, changes will be overwritten
   └─> Will get UnknownMemberIdException

2. Consider impact on state
   ├─> Stream processing apps maintain state
   ├─> Reprocessing data may need state reset
   └─> Example: Count of shoes sold must be reset too

3. Check auto.offset.reset
   ├─> Determines behavior when no offset found
   └─> Better to explicitly set than rely on config
```

**Complete example:**

```java
// Step 1: Get earliest offsets for all partitions
Map<TopicPartition, OffsetSpec> requestEarliestOffsets = new HashMap<>();
for (TopicPartition tp : partitions) {
    requestEarliestOffsets.put(tp, OffsetSpec.earliest());
}

Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> earliestOffsets =
    admin.listOffsets(requestEarliestOffsets).all().get();

// Step 2: Convert to OffsetAndMetadata format
Map<TopicPartition, OffsetAndMetadata> resetOffsets = new HashMap<>();
for (Map.Entry<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> e :
        earliestOffsets.entrySet()) {
    resetOffsets.put(e.getKey(),
        new OffsetAndMetadata(e.getValue().offset()));
}

// Step 3: Update the consumer group offsets
try {
    admin.alterConsumerGroupOffsets("my-consumer-group", resetOffsets)
        .all().get();
    System.out.println("Consumer group reset to beginning");
} catch (ExecutionException e) {
    System.out.println("Failed to update offsets: " + e.getMessage());

    if (e.getCause() instanceof UnknownMemberIdException) {
        System.out.println("Consumer group is still active. Stop it first!");
    }
}
```

**Timeline of reset:**

```
Before reset:
Partition: [0][1][2][3][4][5][6][7][8][9]
                          ↑
                    Committed: 6

After reset:
Partition: [0][1][2][3][4][5][6][7][8][9]
            ↑
      Committed: 0

Consumer will reprocess all messages
```

---

## 6. Advanced Operations

### 6.1. Adding Partitions

**When needed:**
- Throughput exceeds partition capacity
- Need more parallelism
- Scaling out consumers

**Risks:**

```
Before adding partitions (4 partitions):
key="user123" → hash % 4 = partition 2 ✓
key="user456" → hash % 4 = partition 1 ✓

After adding partitions (6 partitions):
key="user123" → hash % 6 = partition 5 ✗ (changed!)
key="user456" → hash % 6 = partition 0 ✗ (changed!)

Result:
├─ Old messages for user123: partition 2
├─ New messages for user123: partition 5
└─> Order broken! State scattered!
```

**Adding partitions:**

```java
Map<String, NewPartitions> newPartitions = new HashMap<>();
newPartitions.put("demo-topic",
    NewPartitions.increaseTo(NUM_PARTITIONS + 2)); // Total count!

admin.createPartitions(newPartitions).all().get();
```

**Critical detail:** Specify TOTAL partition count, not number to add!

### 6.2. Deleting Records

**Use case:** Comply with data retention regulations

**How it works:**

```
Before deletion:
Partition: [0][1][2][3][4][5][6][7][8][9]
            ↑                       ↑
       Earliest: 0            Latest: 9

Delete up to offset 5:
admin.deleteRecords({partition: RecordsToDelete.beforeOffset(5)})

After deletion:
Partition: [X][X][X][X][X][5][6][7][8][9]
                          ↑           ↑
                    Earliest: 5  Latest: 9

Deleted records:
├─ Marked as deleted
├─> Consumers cannot access
└─> Physical cleanup happens asynchronously
```

**Example:**

```java
// Step 1: Get offsets for records older than specific time
Long oneMonthAgo = Instant.now().atZone(ZoneId.systemDefault())
    .minusMonths(1).toEpochSecond();

Map<TopicPartition, Long> partitionTimestamps = new HashMap<>();
for (TopicPartition tp : partitions) {
    partitionTimestamps.put(tp, oneMonthAgo);
}

Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> olderOffsets =
    admin.listOffsets(partitionTimestamps).all().get();

// Step 2: Convert to delete records format
Map<TopicPartition, RecordsToDelete> recordsToDelete = new HashMap<>();
for (Map.Entry<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> e :
        olderOffsets.entrySet()) {
    recordsToDelete.put(e.getKey(),
        RecordsToDelete.beforeOffset(e.getValue().offset()));
}

// Step 3: Delete records
admin.deleteRecords(recordsToDelete).all().get();
System.out.println("Deleted records older than one month");
```

### 6.3. Leader Election

**Two types:**

#### Preferred Leader Election

**Purpose:** Rebalance leaders across brokers

```
Scenario: Broker 1 crashed, leadership moved to others
Broker 1 comes back online

Current state:
├─ Partition 0: Leader = Broker 2 (preferred: Broker 1)
├─ Partition 1: Leader = Broker 3 (preferred: Broker 1)
└─> Broker 1 has no leadership (imbalanced!)

After preferred leader election:
├─ Partition 0: Leader = Broker 1 ✓
├─ Partition 1: Leader = Broker 1 ✓
└─> Broker 1 back to normal leadership
```

**Triggering manually:**

```java
Set<TopicPartition> electableTopics = new HashSet<>();
electableTopics.add(new TopicPartition("demo-topic", 0));

try {
    admin.electLeaders(ElectionType.PREFERRED, electableTopics).all().get();
    System.out.println("Preferred leaders elected");
} catch (ExecutionException e) {
    if (e.getCause() instanceof ElectionNotNeededException) {
        System.out.println("Already using preferred leaders");
    }
}
```

#### Unclean Leader Election

**Purpose:** Restore availability when all in-sync replicas gone

**Scenario:**

```
Partition replicas: [Broker 1 (leader), Broker 2, Broker 3]
├─ Broker 1 crashes (leader lost)
├─> Broker 2, 3 not in-sync (missing data)
└─> No eligible leader! Partition UNAVAILABLE

Options:
1. Wait for Broker 1 to come back (may be hours/days)
2. Trigger unclean leader election

Unclean election:
├─> Elect Broker 2 as leader (even though not in-sync)
├─> Partition available again ✓
└─> Data written to Broker 1 is LOST ✗
```

**Critical decision:**

```
Availability vs Durability trade-off
├─ Trigger unclean election: Availability wins (data loss acceptable)
└─ Wait for proper leader: Durability wins (downtime acceptable)
```

### 6.4. Reassigning Replicas

**Use cases:**
- Rebalance load across brokers
- Isolate noisy neighbors
- Decommission broker
- Add replicas for durability

**Example: Adding new broker to cluster**

```java
// Scenario: Had 1 broker (ID=0), added new broker (ID=1)
// Want to spread replicas across both

Map<TopicPartition, Optional<NewPartitionReassignment>> reassignment =
    new HashMap<>();

// Partition 0: Add replica to new broker, keep leader on old broker
reassignment.put(new TopicPartition("demo-topic", 0),
    Optional.of(new NewPartitionReassignment(Arrays.asList(0, 1))));
    // Order matters: first = preferred leader

// Partition 1: Move entirely to new broker
reassignment.put(new TopicPartition("demo-topic", 1),
    Optional.of(new NewPartitionReassignment(Arrays.asList(1))));

// Partition 2: Add replica on new broker, make it preferred leader
reassignment.put(new TopicPartition("demo-topic", 2),
    Optional.of(new NewPartitionReassignment(Arrays.asList(1, 0))));
    // New broker first = preferred leader

// Partition 3: Cancel any ongoing reassignment
reassignment.put(new TopicPartition("demo-topic", 3),
    Optional.empty());

admin.alterPartitionReassignments(reassignment).all().get();

// Check progress
Map<TopicPartition, PartitionReassignment> ongoing =
    admin.listPartitionReassignments().reassignments().get();
System.out.println("Currently reassigning: " + ongoing);
```

**What happens:**

```
Reassignment process:
1. New replicas start catching up (fetch from leader)
2. Once caught up, new replicas added to ISR
3. Old replicas (if any) removed
4. Leader changes (if needed) after next preferred election

Timeline:
├─ Start: [Old replica locations]
├─> Copying data: [Old replicas + New replicas]
├─> Caught up: [New replicas in ISR]
└─> Complete: [New replica locations]

Note: Large partitions take time to copy!
      Use quotas to throttle if needed.
```

---

## 7. Working with Futures

**The blocking pattern (simple but slow):**

```java
DescribeTopicsResult result = admin.describeTopics(topics);
TopicDescription desc = result.values().get("my-topic").get(); // BLOCKS
```

**The async pattern (efficient for servers):**

```java
// Example: HTTP server that describes topics
vertx.createHttpServer().requestHandler(request -> {
    String topic = request.getParam("topic");
    int timeout = Integer.parseInt(request.getParam("timeout"));

    DescribeTopicsResult result = admin.describeTopics(
        Collections.singletonList(topic),
        new DescribeTopicsOptions().timeoutMs(timeout));

    // Attach callback instead of blocking
    result.values().get(topic).whenComplete(
        (topicDescription, throwable) -> {
            if (throwable != null) {
                request.response().end(
                    "Error: " + throwable.getMessage());
            } else {
                request.response().end(
                    topicDescription.toString());
            }
        });
}).listen(8080);
```

**Why this matters:**

```
Blocking approach:
Request 1: Describe topic (timeout=60s) → BLOCKS thread for 60s
Request 2: Describe topic (timeout=5s)  → Waits behind Request 1
           └─> Takes 60s+ even with 5s timeout!

Async approach:
Request 1: Describe topic (timeout=60s) → Returns Future
Request 2: Describe topic (timeout=5s)  → Returns Future
           └─> Both execute concurrently
           └─> Request 2 completes in ~5s ✓
```

> **💡 Insight**
>
> Use blocking pattern for batch scripts and CLI tools. Use async pattern for servers and applications handling concurrent requests. The API supports both styles equally well.

---

## 8. Testing with MockAdminClient

**MockAdminClient: Test without real Kafka**

**Example class to test:**

```java
public class TopicCreator {
    private final AdminClient admin;

    public TopicCreator(AdminClient admin) {
        this.admin = admin;
    }

    public void maybeCreateTopic(String topicName)
            throws ExecutionException, InterruptedException {
        if (topicName.toLowerCase().startsWith("test")) {
            Collection<NewTopic> topics = new ArrayList<>();
            topics.add(new NewTopic(topicName, 1, (short) 1));
            admin.createTopics(topics);

            // Also make it compacted
            ConfigResource configResource = new ConfigResource(
                ConfigResource.Type.TOPIC, topicName);
            ConfigEntry compaction = new ConfigEntry(
                TopicConfig.CLEANUP_POLICY_CONFIG,
                TopicConfig.CLEANUP_POLICY_COMPACT);
            Collection<AlterConfigOp> configOp = new ArrayList<>();
            configOp.add(new AlterConfigOp(compaction, AlterConfigOp.OpType.SET));
            Map<ConfigResource, Collection<AlterConfigOp>> alterConf =
                new HashMap<>();
            alterConf.put(configResource, configOp);
            admin.incrementalAlterConfigs(alterConf).all().get();
        }
    }
}
```

**Setting up the mock:**

```java
@Before
public void setUp() {
    Node broker = new Node(0, "localhost", 9092);
    this.admin = spy(new MockAdminClient(
        Collections.singletonList(broker), broker));

    // MockAdminClient doesn't implement incrementalAlterConfigs
    // Need to mock it to avoid UnsupportedOperationException
    AlterConfigsResult emptyResult = mock(AlterConfigsResult.class);
    doReturn(KafkaFuture.completedFuture(null))
        .when(emptyResult).all();
    doReturn(emptyResult)
        .when(admin).incrementalAlterConfigs(any());
}
```

**Writing tests:**

```java
@Test
public void testCreateTestTopic()
        throws ExecutionException, InterruptedException {
    TopicCreator tc = new TopicCreator(admin);
    tc.maybeCreateTopic("test.is.a.test.topic");

    // Verify createTopics was called once
    verify(admin, times(1)).createTopics(any());
}

@Test
public void testNotTestTopic()
        throws ExecutionException, InterruptedException {
    TopicCreator tc = new TopicCreator(admin);
    tc.maybeCreateTopic("not.a.test");

    // Verify createTopics was never called
    verify(admin, never()).createTopics(any());
}
```

**MockAdminClient capabilities:**

```
Mocked (works):
├─ createTopics() → Following listTopics() returns them
├─ listTopics() → Returns topics "created" with createTopics()
└─> Enough for many test scenarios

Not mocked (may throw):
└─> incrementalAlterConfigs() → Can inject your own implementation
```

**Maven dependency:**

```xml
<dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>2.5.0</version>
    <classifier>test</classifier>
    <scope>test</scope>
</dependency>
```

---

## 9. Summary

**What we learned:**

1. **AdminClient Basics**:
   - Asynchronous API (returns Futures immediately)
   - Eventually consistent (changes take time to propagate)
   - Flat hierarchy (everything in one class)

2. **Topic Management**:
   - List, describe, create, delete topics
   - Validate configurations programmatically
   - Check and create topics on application startup

3. **Configuration Management**:
   - Read and modify broker/topic configurations
   - Filter non-default configurations
   - Use during emergencies to dump/restore configs

4. **Consumer Group Management**:
   - List and describe consumer groups
   - Calculate consumer lag
   - Modify offsets for reprocessing (reset to beginning/specific time)

5. **Advanced Operations**:
   - Add partitions (breaks key-to-partition mapping!)
   - Delete records (compliance with retention laws)
   - Trigger leader elections (preferred or unclean)
   - Reassign replicas (rebalance load, decommission brokers)

6. **Working with Futures**:
   - Blocking: Simple, suitable for scripts/CLI
   - Async: Efficient, suitable for servers

7. **Testing**:
   - MockAdminClient for unit tests
   - Some methods mocked, others need manual injection

**Key takeaway:** AdminClient is the Swiss Army knife for Kafka operations. It's essential for application developers who need dynamic topic management and for SREs who need to build tooling and automation. Learn it before you need it in an emergency!

---

**Previous:** [Chapter 4: Kafka Consumers](./chapter4.md) | **Next:** [Chapter 6: Kafka Internals →](./chapter6.md)
