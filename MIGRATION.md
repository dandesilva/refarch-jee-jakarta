# Jakarta EE Migration Guide

This document provides a comprehensive guide for migrating legacy JavaEE applications to Jakarta EE 10, based on the actual migration of the Customer Order Services application.

## Table of Contents

- [Overview](#overview)
- [Migration Strategy](#migration-strategy)
- [Step-by-Step Guide](#step-by-step-guide)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Testing and Validation](#testing-and-validation)
- [Rollback Plan](#rollback-plan)

---

## Overview

### What Changed

The migration transformed a JavaEE 5/6 application into a modern Jakarta EE 10 application:

| Aspect | Before | After |
|--------|--------|-------|
| Java Version | 1.6 | 11 |
| Platform | JavaEE 5/6 | Jakarta EE 10 |
| App Server | IBM WebSphere Liberty | WildFly 31 |
| Database | IBM DB2 | PostgreSQL 15 |
| JPA Provider | Apache OpenJPA | Hibernate 6.4.4 |
| JSON Library | IBM com.ibm.json | org.json |
| Jackson | Codehaus (1.x) | FasterXML (2.x) |

### Why Migrate?

- **Vendor Independence** - Move away from IBM-specific dependencies
- **Modern Standards** - Align with Jakarta EE specifications
- **Cloud Native** - Enable containerization and cloud deployment
- **Long-term Support** - Jakarta EE is actively maintained
- **Performance** - Benefit from modern JVM and runtime improvements

---

## Migration Strategy

### 1. Assessment Phase

**Inventory your dependencies:**
```bash
# Find all JavaEE dependencies
grep -r "javax" pom.xml

# Find IBM-specific dependencies
grep -r "com.ibm" pom.xml

# Identify proprietary APIs
grep -r "javax.naming.InitialContext" src/
```

**Key questions:**
- What JavaEE version are you using?
- Are there vendor-specific extensions?
- What's your current Java version?
- Do you have database dependencies?

### 2. Planning Phase

**Recommended approach:**
1. Upgrade Java version first (if needed)
2. Update Maven POMs
3. Migrate package names
4. Update XML descriptors
5. Test incrementally
6. Containerize

**Timeline:** Budget 2-4 weeks for a medium-sized application.

### 3. Execution Phase

Follow the step-by-step guide below.

---

## Step-by-Step Guide

### Step 1: Upgrade Java Version

**Parent POM (`pom.xml`):**
```xml
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
</properties>
```

**Validate:**
```bash
mvn clean compile
```

### Step 2: Update Maven Dependencies

**Remove JavaEE dependencies:**
```xml
<!-- REMOVE -->
<dependency>
    <groupId>javax</groupId>
    <artifactId>javaee-api</artifactId>
    <version>6.0</version>
</dependency>
```

**Add Jakarta EE dependencies:**
```xml
<!-- ADD -->
<dependency>
    <groupId>jakarta.platform</groupId>
    <artifactId>jakarta.jakartaee-api</artifactId>
    <version>10.0.0</version>
    <scope>provided</scope>
</dependency>
```

**Update dependency management in parent POM:**
```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>jakarta.platform</groupId>
            <artifactId>jakarta.jakartaee-api</artifactId>
            <version>10.0.0</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### Step 3: Update EJB and WAR Plugin Versions

**EJB Module:**
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-ejb-plugin</artifactId>
    <version>3.2.1</version>
    <configuration>
        <ejbVersion>4.0</ejbVersion>  <!-- Changed from 3.0 -->
    </configuration>
</plugin>
```

**WAR Module:**
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-war-plugin</artifactId>
    <version>3.3.2</version>
</plugin>
```

### Step 4: Migrate Package Names

**Automated approach using sed:**

```bash
# Navigate to source directory
cd src/main/java

# JPA/Persistence
find . -name "*.java" -exec sed -i '' 's/import javax\.persistence\./import jakarta.persistence./g' {} +

# EJB
find . -name "*.java" -exec sed -i '' 's/import javax\.ejb\./import jakarta.ejb./g' {} +

# JAX-RS
find . -name "*.java" -exec sed -i '' 's/import javax\.ws\.rs\./import jakarta.ws.rs./g' {} +

# CDI
find . -name "*.java" -exec sed -i '' 's/import javax\.enterprise\./import jakarta.enterprise./g' {} +
find . -name "*.java" -exec sed -i '' 's/import javax\.inject\./import jakarta.inject./g' {} +

# Annotations
find . -name "*.java" -exec sed -i '' 's/import javax\.annotation\./import jakarta.annotation./g' {} +

# Servlet (if applicable)
find . -name "*.java" -exec sed -i '' 's/import javax\.servlet\./import jakarta.servlet./g' {} +

# Validation
find . -name "*.java" -exec sed -i '' 's/import javax\.validation\./import jakarta.validation./g' {} +
```

**Manual verification:**
- Review each changed file
- Check for any missed occurrences
- Verify no breaking changes in APIs

### Step 5: Update XML Descriptors

**web.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app version="5.0" 
         xmlns="https://jakarta.ee/xml/ns/jakartaee" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee 
                             https://jakarta.ee/xml/ns/jakartaee/web-app_5_0.xsd">
    <!-- Your configuration -->
</web-app>
```

**persistence.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<persistence version="3.0" 
             xmlns="https://jakarta.ee/xml/ns/persistence" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
             xsi:schemaLocation="https://jakarta.ee/xml/ns/persistence 
                                 https://jakarta.ee/xml/ns/persistence/persistence_3_0.xsd">
    <persistence-unit name="YourPU">
        <jta-data-source>java:/jdbc/yourds</jta-data-source>
        <properties>
            <!-- For Hibernate -->
            <property name="hibernate.dialect" value="org.hibernate.dialect.PostgreSQLDialect" />
            <property name="hibernate.hbm2ddl.auto" value="none" />
        </properties>
    </persistence-unit>
</persistence>
```

### Step 6: Migrate Third-Party Libraries

**Jackson (if used):**
```xml
<!-- REMOVE Codehaus Jackson -->
<!--
<dependency>
    <groupId>org.codehaus.jackson</groupId>
    <artifactId>jackson-mapper-asl</artifactId>
</dependency>
-->

<!-- ADD FasterXML Jackson -->
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-annotations</artifactId>
    <version>2.15.2</version>
    <scope>provided</scope>
</dependency>
```

**Update imports in code:**
```java
// Before
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonProperty;

// After
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
```

**JSON Processing:**
```xml
<!-- For org.json (simple cases) -->
<dependency>
    <groupId>org.json</groupId>
    <artifactId>json</artifactId>
    <version>20230227</version>
</dependency>
```

### Step 7: Update Code Patterns

**Replace JNDI lookups with CDI injection:**

Before:
```java
@Path("/Product")
public class ProductResource {
    protected ProductSearchService productSearch;
    
    public ProductResource() {
        try {
            InitialContext context = new InitialContext();
            productSearch = (ProductSearchService)context.lookup(
                "java:module/ProductSearchServiceImpl");
        } catch (NamingException e) {
            e.printStackTrace();
        }
    }
}
```

After:
```java
@Path("/Product")
@RequestScoped
public class ProductResource {
    @EJB
    ProductSearchService productSearch;
    
    // Constructor removed - injection handles it!
}
```

**Key changes:**
1. Add `@RequestScoped` annotation
2. Replace constructor-based JNDI lookup with `@EJB` injection
3. Remove `InitialContext` and exception handling

### Step 8: Handle JSON-B Serialization

If your application server uses JSON-B (like WildFly), add JSON-B annotations:

```java
import jakarta.json.bind.annotation.JsonbTransient;

@Entity
public class Product {
    @ManyToMany
    @JsonbTransient  // Exclude from JSON serialization
    private Collection<Category> categories;
    
    @JsonbTransient
    public Collection<Category> getCategories() {
        return categories;
    }
}
```

**When to use:**
- Circular references between entities
- Collections that cause infinite loops
- Fields you don't want in JSON output

### Step 9: Database Migration (if needed)

If migrating from DB2 to PostgreSQL:

**Schema conversion:**
```sql
-- DB2
CREATE TABLE PRODUCT (
    PRODUCT_ID INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    DESCRIPTION CLOB(1M)
)

-- PostgreSQL
CREATE TABLE PRODUCT (
    PRODUCT_ID SERIAL PRIMARY KEY,
    DESCRIPTION TEXT
)
```

**Key changes:**
- `GENERATED ALWAYS AS IDENTITY` → `SERIAL`
- `CLOB(size)` → `TEXT`
- Most other types compatible

### Step 10: Build and Test

```bash
# Clean build
mvn clean package

# Check for compilation errors
# Review warnings

# Run tests
mvn test
```

---

## Common Issues and Solutions

### Issue 1: Cannot find symbol javax.*

**Error:**
```
[ERROR] cannot find symbol
symbol:   class EntityManager
location: package javax.persistence
```

**Solution:**
- Verify all `javax.*` imports changed to `jakarta.*`
- Use automated search/replace (see Step 4)
- Check IDE auto-imports aren't adding javax

### Issue 2: EJB Injection Returns Null

**Error:**
```java
NullPointerException: Cannot invoke because this.productSearch is null
```

**Solution:**
Add `@RequestScoped` to your JAX-RS resource:
```java
@Path("/Product")
@RequestScoped  // THIS IS REQUIRED
public class ProductResource {
    @EJB
    ProductSearchService productSearch;
}
```

### Issue 3: EJBAccessException - Not Allowed

**Error:**
```
jakarta.ejb.EJBAccessException: Invocation on method... is not allowed
```

**Solution:**
Add security annotation to EJB:
```java
@Stateless
@PermitAll  // For demo/testing
// OR
@RolesAllowed("YourRole")  // For production
public class YourServiceImpl implements YourService {
}
```

### Issue 4: JSON Serialization Error

**Error:**
```
JSON Binding serialization error: Unable to serialize property 'categories'
```

**Solution:**
Add `@JsonbTransient` to problematic properties:
```java
@JsonbTransient
public Collection<Category> getCategories() {
    return categories;
}
```

### Issue 5: Hibernate Dialect Not Detected

**Error:**
```
HibernateException: Unable to determine Dialect without JDBC metadata
```

**Solution:**
Add dialect explicitly in `persistence.xml`:
```xml
<property name="hibernate.dialect" 
          value="org.hibernate.dialect.PostgreSQLDialect" />
```

### Issue 6: JNDI Name Format Error

**Error:**
```
IllegalArgumentException: Illegal context in name: java:jdbc/orderds
```

**Solution:**
Add leading slash:
```
java:jdbc/orderds  ❌
java:/jdbc/orderds ✅
```

### Issue 7: Module Not Found in WildFly

**Error:**
```
Module org.postgresql not found
```

**Solution:**
Verify WildFly module structure:
```
$WILDFLY_HOME/modules/system/layers/base/org/postgresql/main/
├── postgresql-42.7.1.jar
└── module.xml
```

---

## Testing and Validation

### Unit Tests

```bash
mvn test
```

**Update test dependencies:**
```xml
<dependency>
    <groupId>org.jboss.arquillian.junit</groupId>
    <artifactId>arquillian-junit-container</artifactId>
    <version>1.7.0.Final</version>
    <scope>test</scope>
</dependency>
```

### Integration Tests

```bash
# Start containers
podman-compose up -d

# Run integration tests
mvn verify -P integration-tests

# Check logs
podman logs customerorder-app
```

### Manual Testing

```bash
# Health check
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1

# Expected: JSON response with product details
```

### Performance Testing

Compare before/after:
- Application startup time
- Response times for common operations
- Memory usage
- Database connection pool efficiency

---

## Rollback Plan

### If Migration Fails

1. **Keep original code in separate branch:**
```bash
git checkout -b jakarta-migration
# Do all migration work here
# Keep main/master untouched
```

2. **Tag important milestones:**
```bash
git tag -a v1.0-javaee "Last stable JavaEE version"
git tag -a v2.0-jakarta "First Jakarta EE version"
```

3. **Document known issues:**
- Create GitHub issues for each blocker
- Maintain migration log
- Track workarounds

4. **Parallel deployment:**
- Run both versions side-by-side
- Gradually shift traffic
- Monitor for issues

---

## Migration Checklist

- [ ] Java version upgraded
- [ ] Parent POM updated with Jakarta EE dependencies
- [ ] All module POMs updated
- [ ] Package names migrated (`javax.*` → `jakarta.*`)
- [ ] XML descriptors updated (web.xml, persistence.xml, etc.)
- [ ] Third-party libraries migrated
- [ ] Code patterns updated (JNDI → CDI)
- [ ] JSON-B annotations added where needed
- [ ] Security annotations reviewed
- [ ] Database migration completed (if applicable)
- [ ] Build successful (`mvn clean package`)
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] Performance validated
- [ ] Documentation updated
- [ ] Deployment guide created
- [ ] Rollback plan documented

---

## Additional Resources

### Official Documentation
- [Jakarta EE 10 Specification](https://jakarta.ee/specifications/platform/10/)
- [WildFly Documentation](https://docs.wildfly.org/31/)
- [Hibernate 6 Migration Guide](https://hibernate.org/orm/documentation/6.4/)

### Tools
- [Eclipse Transformer](https://github.com/eclipse/transformer) - Automated javax → jakarta conversion
- [OpenRewrite](https://docs.openrewrite.org/) - Code migration recipes
- [Maven Modernizer Plugin](https://github.com/gaul/modernizer-maven-plugin) - Detect deprecated APIs

### Community
- [Jakarta EE Mailing Lists](https://jakarta.ee/connect/)
- [WildFly Forums](https://groups.google.com/g/wildfly)
- [Stack Overflow - jakarta-ee tag](https://stackoverflow.com/questions/tagged/jakarta-ee)

---

## Conclusion

Migrating to Jakarta EE is a significant but worthwhile effort. The benefits of modern standards, vendor independence, and cloud-native capabilities justify the investment.

This guide is based on a real-world migration completed in April 2026. Your mileage may vary, but the principles remain the same.

**Questions?** Check the [session logs](docs/session-logs/) for detailed troubleshooting examples.

---

**Last Updated:** April 3, 2026  
**Migration Version:** JavaEE 6 → Jakarta EE 10  
**Success Rate:** 100% (with documented workarounds)
