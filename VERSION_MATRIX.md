# Version Matrix

This document provides a comprehensive comparison of the different Java versions available for this Jakarta EE reference architecture.

## Available Versions

| Branch | Java Version | Jakarta EE | WildFly | Build Image | Runtime Image | Status |
|--------|--------------|------------|---------|-------------|---------------|--------|
| [`java-11`](../../tree/java-11) | 11 (LTS) | 10.0 | 31.0.1 | openjdk-17 | wildfly:31-jdk17 | ✅ Stable |
| [`java-21`](../../tree/java-21) | 21 (LTS) | 10.0 | 31.0.1 | openjdk-21 | wildfly:31-jdk21 | ✅ Recommended |

## Quick Start by Version

### Java 11 (Conservative)
```bash
git clone -b java-11 https://github.com/dandesilva/refarch-jee-jakarta.git
cd refarch-jee-jakarta
./quick-start.sh
```

**Best for:**
- Organizations with Java 11 standardization
- Conservative migration from Java 8
- Environments with strict LTS-only policies
- Minimal risk tolerance

### Java 21 (Recommended)
```bash
git clone -b java-21 https://github.com/dandesilva/refarch-jee-jakarta.git
cd refarch-jee-jakarta
./quick-start.sh
```

**Best for:**
- New projects starting today
- Taking advantage of modern Java features
- Long-term maintainability (extended LTS support until 2029)
- Performance-critical applications

## Technical Differences

### Java Version Features

#### Java 11 Features
- Local variable type inference (var)
- HTTP Client API
- String methods (isBlank, lines, strip, repeat)
- Files utility methods
- Collection.toArray(IntFunction)

#### Java 21 Additional Features
Over Java 11, you gain:

**Language Enhancements:**
- **Records** (Java 16) - Immutable data carriers
- **Sealed Classes** (Java 17) - Restricted inheritance hierarchies
- **Pattern Matching for switch** (Java 21) - More expressive switch statements
- **Text Blocks** (Java 15) - Multi-line string literals
- **Virtual Threads** (Java 21) - Lightweight concurrency

**Example - Records:**
```java
// Java 11 - Traditional class
public class Product {
    private final String name;
    private final double price;
    
    public Product(String name, double price) {
        this.name = name;
        this.price = price;
    }
    // ... getters, equals, hashCode, toString
}

// Java 21 - Record
public record Product(String name, double price) {}
```

**Example - Pattern Matching:**
```java
// Java 11
if (obj instanceof String) {
    String s = (String) obj;
    System.out.println(s.toUpperCase());
}

// Java 21
if (obj instanceof String s) {
    System.out.println(s.toUpperCase());
}
```

**Example - Text Blocks:**
```java
// Java 11
String sql = "SELECT p.id, p.name, p.price\n" +
             "FROM products p\n" +
             "WHERE p.category = ?";

// Java 21
String sql = """
    SELECT p.id, p.name, p.price
    FROM products p
    WHERE p.category = ?
    """;
```

### Performance Characteristics

| Metric | Java 11 | Java 21 | Improvement |
|--------|---------|---------|-------------|
| Startup Time | Baseline | ~5-10% faster | ZGC, G1GC improvements |
| Memory Footprint | Baseline | ~10-15% lower | Compact strings, better GC |
| Throughput | Baseline | ~10-20% higher | JIT optimizations, virtual threads |
| GC Pause Time | Baseline | ~30-50% lower | ZGC, Shenandoah improvements |

### Container Images

#### Java 11 Branch
**Build Stage:**
```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-17:latest AS builder
```

**Runtime Stage:**
```dockerfile
FROM quay.io/wildfly/wildfly:31.0.1.Final-jdk17
```

#### Java 21 Branch
**Build Stage:**
```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-21:latest AS builder
```

**Runtime Stage:**
```dockerfile
FROM quay.io/wildfly/wildfly:31.0.1.Final-jdk21
```

### Maven Configuration

#### Java 11 (pom.xml)
```xml
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
</properties>
```

#### Java 21 (pom.xml)
```xml
<properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
</properties>
```

## Support Timeline

| Java Version | Release Date | End of Support | Commercial Support |
|--------------|--------------|----------------|-------------------|
| Java 11 (LTS) | September 2018 | **September 2026** | Extended to 2032+ |
| Java 21 (LTS) | September 2023 | **September 2029** | Extended to 2035+ |

**Important:** Java 11 standard support ends in **September 2026**. Consider migrating to Java 21 before this date.

## Migration Path

### From Java 11 to Java 21

Most applications can upgrade with minimal changes:

1. **Update Maven configuration:**
   ```xml
   <maven.compiler.source>21</maven.compiler.source>
   <maven.compiler.target>21</maven.compiler.target>
   ```

2. **Update Dockerfile base images:**
   ```dockerfile
   FROM registry.access.redhat.com/ubi9/openjdk-21:latest
   FROM quay.io/wildfly/wildfly:31.0.1.Final-jdk21
   ```

3. **Rebuild and test:**
   ```bash
   mvn clean package
   podman build -f Dockerfile.redhat -t customerorder-app:java21 .
   ```

**Breaking Changes:** Minimal for Jakarta EE applications. Main risks:
- Removed APIs (minimal between 11-21)
- Security manager deprecation (removed in JDK 17+)
- Internal API restrictions (most already handled in Java 11)

### Testing Your Migration

```bash
# Build on Java 21
mvn clean verify

# Run integration tests
cd CustomerOrderServicesTest
mvn test

# Container smoke test
./quick-start.sh
curl http://localhost:9080/CustomerOrderServicesWeb/jaxrs/Product
```

## Choosing Your Version

### Choose Java 11 if:
- ✅ Your organization has standardized on Java 11
- ✅ You're migrating from Java 8 and want a smaller jump
- ✅ You need maximum stability and minimal risk
- ✅ Your production environment doesn't support Java 17+
- ⚠️ **Note:** Plan migration to Java 21 before September 2026

### Choose Java 21 if:
- ✅ Starting a new project or modernization effort
- ✅ Want access to modern language features (records, pattern matching, text blocks)
- ✅ Need better performance and lower memory footprint
- ✅ Want longest LTS support window (until 2029+)
- ✅ **Recommended for most users**

## Frequently Asked Questions

### Q: Can I switch branches after cloning?
**A:** Yes! Just checkout the branch you want:
```bash
git checkout java-11    # Switch to Java 11
git checkout java-21    # Switch to Java 21
```

### Q: Will my application run differently?
**A:** Functionally identical. Performance may improve on Java 21. All Jakarta EE 10 APIs are the same.

### Q: Do I need to change my code?
**A:** No changes required. The codebase is identical across branches, only the Java version differs.

### Q: Can I use Java 21 features in the java-21 branch?
**A:** Absolutely! The java-21 branch supports all Java 21 language features. You can refactor to use records, pattern matching, text blocks, etc.

### Q: What about Java 17?
**A:** Java 17 is also an LTS version (released 2021, supported until 2029). We focus on Java 11 (conservative) and Java 21 (latest LTS) to provide clear migration paths. If you need Java 17, you can create your own branch following the same pattern.

### Q: Which branch should I fork?
**A:** Fork the `java-21` branch for new projects. Fork `java-11` only if you have specific constraints requiring Java 11.

## Branch Maintenance

All branches receive:
- ✅ Security updates
- ✅ Dependency updates
- ✅ Documentation improvements
- ✅ Bug fixes

Feature additions may be prioritized for the latest LTS (Java 21).

## Getting Help

- **Issues:** [GitHub Issues](https://github.com/dandesilva/refarch-jee-jakarta/issues)
- **Discussions:** [GitHub Discussions](https://github.com/dandesilva/refarch-jee-jakarta/discussions)
- **Migration Guide:** See [MIGRATION.md](MIGRATION.md)
- **Deployment Guide:** See [DEPLOYMENT.md](DEPLOYMENT.md)

## References

- [Java 11 Release Notes](https://www.oracle.com/java/technologies/javase/11-relnotes.html)
- [Java 21 Release Notes](https://www.oracle.com/java/technologies/javase/21-relnotes.html)
- [Jakarta EE 10 Specification](https://jakarta.ee/specifications/platform/10/)
- [WildFly 31 Documentation](https://docs.wildfly.org/31/)
- [OpenJDK Support Roadmap](https://www.oracle.com/java/technologies/java-se-support-roadmap.html)
