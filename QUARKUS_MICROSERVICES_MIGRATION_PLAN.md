Now I have enough information. Let me create a comprehensive implementation plan.

---

# Implementation Plan: Quarkus Migration & Microservices Decomposition

## Executive Summary

This plan outlines a **staged approach** to refactoring the refarch-jee-jakarta project. The recommendation is to migrate to Quarkus first, then decompose into microservices, rather than attempting both simultaneously. This reduces risk and allows for validation at each phase.

## Current State Analysis

### Architecture Overview
The application is a classic Jakarta EE monolith with clear service boundaries:

**Business Logic Layer (EJBs)**
- `ProductSearchServiceImpl`: 4 operations (loadProduct, loadCategory, loadProductsByCategory, getTopLevelCategories)
- `CustomerOrderServicesImpl`: 8 operations (loadCustomer, openOrder, addLineItem, removeLineItem, submit, loadCustomerHistory, updateAddress, updateInfo)

**Data Model**
- Product domain: Product, Category (many-to-many relationship)
- Customer domain: AbstractCustomer, BusinessCustomer, ResidentialCustomer, Address (embedded)
- Order domain: Order, LineItem
- **Critical dependency**: CustomerOrderServicesImpl validates products when adding line items (line 48: `em.find(Product.class, productId)`)

**Technology Stack**
- Packaging: EAR with EJB + WAR modules
- Persistence: JPA with Hibernate, PostgreSQL
- REST: JAX-RS resources with @RequestScoped
- Security: SessionContext for user principal, BASIC auth with SecureShopper role
- Transactions: @PersistenceContext with JTA datasource

### Key Observations
1. **Clean separation exists** between product catalog and customer/order logic
2. **Tight coupling on Product validation** in order service (cross-domain dependency)
3. **Shared entity model** - all entities in single persistence unit
4. **Optimistic locking** on Order entity using @Version
5. **Security context dependency** - SessionContext.getCallerPrincipal() used for user lookup
6. **JPA lifecycle hooks** in LineItem for order total calculation

## Strategic Recommendation: Staged Approach

### Why Staged vs. Big Bang?

**Staged Approach (Recommended)**
- Validate Quarkus migration works before introducing distributed complexity
- Team learns Quarkus patterns incrementally
- Easier rollback at each phase
- Database can remain shared initially
- Lower risk profile

**Big Bang Approach (Not Recommended)**
- High complexity - two major changes simultaneously
- Difficult to isolate issues
- All-or-nothing deployment
- Requires distributed transactions or saga patterns from day 1

---

## PHASE 1: Quarkus Migration (Monolith on Quarkus)

**Goal**: Migrate from WildFly to Quarkus while maintaining monolithic architecture

**Duration**: 3-4 weeks

### Phase 1A: Setup and Dependencies (Week 1)

#### Step 1.1: Project Structure Transformation

**Current Structure:**
```
CustomerOrderServicesProject/  (parent POM)
├── CustomerOrderServices/     (EJB JAR)
├── CustomerOrderServicesWeb/  (WAR)
└── CustomerOrderServicesApp/  (EAR)
```

**Target Structure:**
```
refarch-jee-quarkus/
├── pom.xml                    (Quarkus parent)
├── src/main/java/
│   ├── org/pwte/example/domain/       (JPA entities - unchanged)
│   ├── org/pwte/example/service/      (services - converted)
│   ├── org/pwte/example/resources/    (JAX-RS - minimal changes)
│   └── org/pwte/example/exception/    (unchanged)
├── src/main/resources/
│   ├── application.properties         (Quarkus config)
│   ├── META-INF/persistence.xml       (optional - can use application.properties)
│   └── import.sql                     (optional for dev mode)
└── src/main/docker/
    └── Dockerfile.jvm
```

**Actions:**
- Create new Quarkus project: `quarkus create app org.pwte.example:customer-order-services`
- Copy domain, service, resources, exception packages to new structure
- Update parent POM with Quarkus BOM

#### Step 1.2: Dependency Mapping

**WildFly (Jakarta EE) → Quarkus Extensions**

| Current | Quarkus Extension | Notes |
|---------|------------------|-------|
| jakarta.jakartaee-api | quarkus-resteasy-reactive-jackson | RESTEasy Reactive is recommended over Classic |
| EJB (@Stateless) | quarkus-arc (CDI) | Use @ApplicationScoped instead |
| JPA (@PersistenceContext) | quarkus-hibernate-orm-panache | Or use standard hibernate-orm |
| PostgreSQL driver | quarkus-jdbc-postgresql | |
| JAX-RS | quarkus-resteasy-reactive | |
| JSON-B | quarkus-resteasy-reactive-jackson | Jackson preferred |
| Security (SessionContext) | quarkus-security | Use SecurityIdentity |

**New pom.xml dependencies:**
```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>io.quarkus.platform</groupId>
      <artifactId>quarkus-bom</artifactId>
      <version>3.10.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-resteasy-reactive-jackson</artifactId>
  </dependency>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-orm</artifactId>
  </dependency>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jdbc-postgresql</artifactId>
  </dependency>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-security</artifactId>
  </dependency>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-elytron-security-properties-file</artifactId>
  </dependency>
  <dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-openapi</artifactId>
  </dependency>
</dependencies>
```

#### Step 1.3: Configuration Migration

**From**: WildFly datasource CLI configuration  
**To**: `application.properties`

```properties
# Database configuration
quarkus.datasource.db-kind=postgresql
quarkus.datasource.username=db2inst1
quarkus.datasource.password=db2inst1
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB

# Hibernate ORM
quarkus.hibernate-orm.database.generation=none
quarkus.hibernate-orm.log.sql=false
quarkus.hibernate-orm.dialect=org.hibernate.dialect.PostgreSQLDialect

# HTTP
quarkus.http.port=8080

# Security
quarkus.security.users.file.enabled=true
quarkus.security.users.file.users=users.properties
quarkus.security.users.file.roles=roles.properties
quarkus.security.users.file.realm-name=CustomerOrderRealm

# Application
quarkus.http.root-path=/CustomerOrderServicesWeb
quarkus.resteasy.path=/jaxrs
```

### Phase 1B: Code Migration (Week 2)

#### Step 2.1: EJB to CDI Conversion

**Pattern**: Replace @Stateless with @ApplicationScoped

**ProductSearchServiceImpl.java**
```java
// BEFORE
@Stateless
@PermitAll
public class ProductSearchServiceImpl implements ProductSearchService {
    @PersistenceContext
    protected EntityManager em;
}

// AFTER
@ApplicationScoped
public class ProductSearchServiceImpl implements ProductSearchService {
    @Inject
    EntityManager em;
}
```

**CustomerOrderServicesImpl.java**
```java
// BEFORE
@Stateless
@PermitAll
public class CustomerOrderServicesImpl implements CustomerOrderServices {
    @PersistenceContext
    protected EntityManager em;
    
    @Resource 
    SessionContext ctx;
    
    public AbstractCustomer loadCustomer() {
        String user = ctx.getCallerPrincipal().getName();
        // ...
    }
}

// AFTER
@ApplicationScoped
public class CustomerOrderServicesImpl implements CustomerOrderServices {
    @Inject
    EntityManager em;
    
    @Inject
    SecurityIdentity securityIdentity;
    
    public AbstractCustomer loadCustomer() {
        String user = securityIdentity.getPrincipal().getName();
        // ...
    }
}
```

**Trade-offs:**
- **@ApplicationScoped vs @Singleton**: Use @ApplicationScoped for consistency with Jakarta CDI. Both are single instances, but @ApplicationScoped provides proper context propagation.
- **Loss of EJB features**: @Stateless provides instance pooling and some performance optimizations. Quarkus CDI is single-instance but has lower overhead. For this app, impact is minimal.

#### Step 2.2: Security Migration

**SessionContext → SecurityIdentity**

**Before** (CustomerOrderServicesImpl.java line 197):
```java
String user = ctx.getCallerPrincipal().getName();
```

**After**:
```java
String user = securityIdentity.getPrincipal().getName();
```

**Security Configuration:**

Create `src/main/resources/users.properties`:
```properties
rbarcia=password1!
```

Create `src/main/resources/roles.properties`:
```properties
rbarcia=SecureShopper
```

**Update web.xml constraints** to Quarkus annotations:

**Before** (web.xml):
```xml
<security-constraint>
    <web-resource-collection>
        <web-resource-name>Customer</web-resource-name>
        <url-pattern>/jaxrs/Customer</url-pattern>
        <url-pattern>/jaxrs/Customer/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
        <role-name>SecureShopper</role-name>
    </auth-constraint>
</security-constraint>
<login-config>
    <auth-method>BASIC</auth-method>
</login-config>
```

**After** (on CustomerOrderResource.java):
```java
@Path("/Customer")
@RequestScoped
@RolesAllowed("SecureShopper")
@Authenticated
public class CustomerOrderResource {
    // ... existing code
}
```

#### Step 2.3: JAX-RS Resources Update

**Minimal changes required** - JAX-RS resources are largely compatible

**Changes:**
1. Add `@Authenticated` or `@RolesAllowed` annotations (replacing web.xml security)
2. Ensure @Inject is used for service injection (not @EJB)
3. Consider using RESTEasy Reactive annotations for better performance (optional)

**ProductResource.java example:**
```java
@Path("/Product")
@RequestScoped
public class ProductResource {
    @Inject  // Changed from @EJB
    ProductSearchService productSearch;
    
    // Existing methods unchanged
}
```

**CategoryResource.java:**
```java
@Path("/Category")
@RequestScoped
public class CategoryResource {
    @Inject  // Changed from @EJB
    ProductSearchService productSearch;
    
    // Existing methods unchanged
}
```

**CustomerOrderResource.java:**
```java
@Path("/Customer")
@RequestScoped
@RolesAllowed("SecureShopper")  // NEW - replaces web.xml constraint
public class CustomerOrderResource {
    @Inject  // Changed from @EJB
    CustomerOrderServices customerOrderServices;
    
    // Existing methods unchanged
}
```

#### Step 2.4: JPA Entity Migration

**Good news**: JPA entities require minimal changes

**Considerations:**
1. Remove Jackson annotations if migrating to Quarkus Panache (optional)
2. Keep existing JPA lifecycle callbacks (@PrePersist, @PreUpdate, @PreRemove in LineItem)
3. Named queries remain unchanged
4. Persistence unit configuration can move to application.properties

**Optional enhancement - Panache pattern:**
```java
// Option 1: Keep current approach (recommended for Phase 1)
public class Product implements Serializable { ... }

// Option 2: Migrate to Panache (consider for Phase 2)
@Entity
public class Product extends PanacheEntity {
    public String name;
    public BigDecimal price;
    // ... simplified field access
}
```

**Recommendation**: Keep existing entity approach for Phase 1. Consider Panache in Phase 2 if desired.

### Phase 1C: Build and Packaging (Week 3)

#### Step 3.1: Maven Build Configuration

**Update pom.xml with Quarkus plugin:**
```xml
<build>
  <plugins>
    <plugin>
      <groupId>io.quarkus</groupId>
      <artifactId>quarkus-maven-plugin</artifactId>
      <version>${quarkus.version}</version>
      <executions>
        <execution>
          <goals>
            <goal>build</goal>
            <goal>generate-code</goal>
            <goal>generate-code-tests</goal>
          </goals>
        </execution>
      </executions>
    </plugin>
  </plugins>
</build>
```

**Build commands:**
```bash
# Development mode (hot reload)
mvn quarkus:dev

# Package JVM mode
mvn clean package

# Package native mode (optional)
mvn package -Pnative
```

**Output:**
- `target/customer-order-services-0.1.0-SNAPSHOT-runner.jar` (JVM mode)
- `target/customer-order-services-0.1.0-SNAPSHOT-runner` (native mode)

#### Step 3.2: Containerization

**Create Dockerfile.jvm** (replacing Dockerfile.redhat):
```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest

ENV LANGUAGE='en_US:en'

# We make four distinct layers so if there are application changes,
# the library layers can be re-used
COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/
COPY --chown=185 target/quarkus-app/*.jar /deployments/
COPY --chown=185 target/quarkus-app/app/ /deployments/app/
COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185

ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "java", "-jar", "/deployments/quarkus-run.jar" ]
```

**Create Dockerfile.native** (optional):
```dockerfile
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

WORKDIR /work/
RUN chown 1001 /work \
    && chmod "g+rwX" /work \
    && chown 1001:root /work

COPY --chown=1001:root target/*-runner /work/application

EXPOSE 8080
USER 1001

CMD ["./application", "-Dquarkus.http.host=0.0.0.0"]
```

**Benefits over WildFly approach:**
- **Smaller image**: ~150MB (JVM) vs ~800MB (WildFly)
- **Faster startup**: ~1-2s vs ~10-15s
- **Lower memory**: ~100MB vs ~500MB
- **No application server**: Direct Java execution

#### Step 3.3: Database Migration

**No schema changes required** - existing PostgreSQL database works as-is

**Update connection approach:**
```bash
# Before: WildFly required CLI datasource configuration
# After: Environment variables in application.properties

# docker-compose.yml or pod manifest:
environment:
  - QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres-orderdb:5432/ORDERDB
  - QUARKUS_DATASOURCE_USERNAME=db2inst1
  - QUARKUS_DATASOURCE_PASSWORD=db2inst1
```

### Phase 1D: Testing and Validation (Week 4)

#### Step 4.1: Unit Testing

**Add Quarkus test dependencies:**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-junit5</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>io.rest-assured</groupId>
  <artifactId>rest-assured</artifactId>
  <scope>test</scope>
</dependency>
```

**Test pattern:**
```java
@QuarkusTest
public class ProductResourceTest {
    
    @Test
    public void testGetProduct() {
        given()
          .when().get("/CustomerOrderServicesWeb/jaxrs/Product/1")
          .then()
             .statusCode(200)
             .body("name", is("Return of the Jedi"));
    }
}
```

#### Step 4.2: Integration Testing

**Test plan:**
1. Product endpoints (GET /Product/{id}, GET /Product?categoryId=x)
2. Category endpoints (GET /Category, GET /Category/{id})
3. Customer endpoints with authentication
4. Order workflow: open order → add items → remove items → submit
5. Version conflict handling (optimistic locking)
6. Security - unauthenticated requests should fail

**Compatibility verification:**
```bash
# Test existing API contracts
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category
curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1
curl -u rbarcia:password1! http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Customer
```

#### Step 4.3: Performance Testing

**Metrics to compare (WildFly vs Quarkus):**
- Startup time
- Memory consumption (idle, under load)
- Request latency (p50, p95, p99)
- Throughput (requests/second)

**Expected improvements:**
- Startup: 10-15s → 1-2s (JVM mode), <0.1s (native mode)
- Memory: 500MB → 100MB (JVM mode), 50MB (native mode)
- Throughput: Similar or better due to reactive stack

### Phase 1 Rollback Strategy

**If issues arise:**
1. **Before Phase 1B complete**: Continue using WildFly, treat as learning exercise
2. **After Phase 1B, before deployment**: Keep both versions in parallel branches
3. **After deployment**: Blue/green deployment allows instant rollback

**Rollback steps:**
1. Point traffic back to WildFly deployment
2. Investigate Quarkus issues offline
3. Fix and redeploy when ready

**Rollback triggers:**
- Critical API incompatibilities
- Performance degradation >20%
- Security vulnerabilities
- Unresolvable runtime errors

---

## PHASE 2: Microservices Decomposition

**Goal**: Split monolith into three microservices with clear boundaries

**Duration**: 4-6 weeks

**Prerequisites**: Phase 1 complete and stable in production

### Microservices Architecture Design

#### Service Boundaries

**1. Product Catalog Service**
- **Entities**: Product, Category
- **Operations**: loadProduct, loadCategory, loadProductsByCategory, getTopLevelCategories
- **Endpoints**: /Product, /Category
- **Database**: product_catalog_db (or shared schema: product, category, prod_cat tables)

**2. Customer Service**
- **Entities**: AbstractCustomer, BusinessCustomer, ResidentialCustomer, Address
- **Operations**: loadCustomer, updateAddress, updateInfo, getCustomerIdForUser
- **Endpoints**: /Customer (GET, PUT for address/info updates)
- **Database**: customer_db (or shared schema: customer table)

**3. Order Service**
- **Entities**: Order, LineItem
- **Operations**: openOrder, addLineItem, removeLineItem, submit, loadCustomerHistory
- **Endpoints**: /Customer/OpenOrder, /Customer/Orders
- **Database**: order_db (or shared schema: orders, line_item tables)
- **Dependencies**: Calls Product Catalog Service (validate product exists), Customer Service (validate customer exists)

#### Critical Dependency Resolution

**Problem**: CustomerOrderServicesImpl.addLineItem() validates products (line 48):
```java
Product product = em.find(Product.class, productId);
if(product == null) throw new ProductDoesNotExistException();
```

**Solution Options:**

**Option A: Synchronous REST Call (Recommended for Phase 2)**
```java
@ApplicationScoped
public class CustomerOrderServicesImpl implements CustomerOrderServices {
    
    @Inject
    @RestClient
    ProductCatalogClient productClient;
    
    public Order addLineItem(LineItem newLineItem) {
        int productId = newLineItem.getProductId();
        
        // Call Product Catalog Service
        try {
            Product product = productClient.getProduct(productId);
            // Continue with order logic...
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                throw new ProductDoesNotExistException();
            }
            throw e;
        }
    }
}
```

**ProductCatalogClient interface:**
```java
@Path("/Product")
@RegisterRestClient(configKey = "product-catalog-api")
public interface ProductCatalogClient {
    
    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    Product getProduct(@PathParam("id") int productId);
}
```

**Configuration:**
```properties
quarkus.rest-client.product-catalog-api.url=http://product-catalog-service:8080
quarkus.rest-client.product-catalog-api.scope=jakarta.inject.Singleton
```

**Trade-offs:**
- **Pros**: Simple, consistent error handling, transactional clarity
- **Cons**: Latency (additional network call), coupling (Order Service depends on Product Catalog availability)
- **Mitigation**: Circuit breaker pattern, caching

**Option B: Event-Driven (Consider for Phase 3)**
- Product Catalog Service publishes product events (created, updated, deleted)
- Order Service maintains local product cache/read model
- Eventual consistency model
- **Pros**: Decoupling, resilience
- **Cons**: Complexity, data synchronization challenges

**Option C: Shared Database (Interim Step)**
- All services connect to same database
- Product Catalog Service owns product/category tables
- Order Service reads product table (read-only access)
- **Pros**: Minimal code changes, no network calls
- **Cons**: Not true microservices, database coupling

**Recommendation**: Start with Option C (shared database) in Phase 2A, migrate to Option A (REST calls) in Phase 2B.

### Phase 2A: Service Extraction with Shared Database (Weeks 1-2)

#### Step 1.1: Create Three Quarkus Projects

```bash
# From Phase 1 Quarkus monolith, create three services
mvn io.quarkus:quarkus-maven-plugin:create \
  -DprojectGroupId=org.pwte.example \
  -DprojectArtifactId=product-catalog-service \
  -Dextensions="resteasy-reactive-jackson,hibernate-orm,jdbc-postgresql"

mvn io.quarkus:quarkus-maven-plugin:create \
  -DprojectGroupId=org.pwte.example \
  -DprojectArtifactId=customer-service \
  -Dextensions="resteasy-reactive-jackson,hibernate-orm,jdbc-postgresql,security"

mvn io.quarkus:quarkus-maven-plugin:create \
  -DprojectGroupId=org.pwte.example \
  -DprojectArtifactId=order-service \
  -Dextensions="resteasy-reactive-jackson,hibernate-orm,jdbc-postgresql,rest-client,security"
```

**Project Structure:**
```
refarch-jee-microservices/
├── product-catalog-service/
│   ├── src/main/java/
│   │   ├── org/pwte/example/domain/
│   │   │   ├── Product.java
│   │   │   └── Category.java
│   │   ├── org/pwte/example/service/
│   │   │   ├── ProductSearchService.java
│   │   │   └── ProductSearchServiceImpl.java
│   │   └── org/pwte/example/resources/
│   │       ├── ProductResource.java
│   │       └── CategoryResource.java
│   └── pom.xml
├── customer-service/
│   ├── src/main/java/
│   │   ├── org/pwte/example/domain/
│   │   │   ├── AbstractCustomer.java
│   │   │   ├── BusinessCustomer.java
│   │   │   ├── ResidentialCustomer.java
│   │   │   └── Address.java
│   │   ├── org/pwte/example/service/
│   │   │   ├── CustomerService.java (NEW - extracted from CustomerOrderServices)
│   │   │   └── CustomerServiceImpl.java
│   │   └── org/pwte/example/resources/
│   │       └── CustomerResource.java (NEW - customer info endpoints)
│   └── pom.xml
└── order-service/
    ├── src/main/java/
    │   ├── org/pwte/example/domain/
    │   │   ├── Order.java
    │   │   ├── LineItem.java
    │   │   ├── LineItemId.java
    │   │   └── Product.java (read-only copy for shared DB)
    │   ├── org/pwte/example/service/
    │   │   ├── OrderService.java (NEW - extracted from CustomerOrderServices)
    │   │   └── OrderServiceImpl.java
    │   ├── org/pwte/example/resources/
    │   │   └── OrderResource.java (order operations endpoints)
    │   └── org/pwte/example/client/
    │       ├── ProductCatalogClient.java (REST client interface)
    │       └── CustomerClient.java (REST client interface)
    └── pom.xml
```

#### Step 1.2: Entity Distribution

**Product Catalog Service:**
- Product.java (full entity with write access)
- Category.java (full entity with write access)
- persistence.xml includes only Product, Category

**Customer Service:**
- AbstractCustomer.java, BusinessCustomer.java, ResidentialCustomer.java
- Address.java (embedded)
- persistence.xml includes Customer hierarchy

**Order Service:**
- Order.java, LineItem.java, LineItemId.java
- Product.java (read-only copy for validation - temporary in Phase 2A)
- persistence.xml includes Order, LineItem
- **Note**: Product entity here is marked read-only or used only for validation

#### Step 1.3: Database Configuration (Shared Database Approach)

**All three services point to same PostgreSQL database:**

**product-catalog-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB
quarkus.datasource.username=db2inst1
quarkus.datasource.password=db2inst1

# Only manage product/category tables
quarkus.hibernate-orm.database.generation=none
```

**customer-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB
quarkus.datasource.username=db2inst1
quarkus.datasource.password=db2inst1

# Only manage customer table
quarkus.hibernate-orm.database.generation=none
```

**order-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB
quarkus.datasource.username=db2inst1
quarkus.datasource.password=db2inst1

# Manage orders and line_item tables
quarkus.hibernate-orm.database.generation=none

# REST client configuration
quarkus.rest-client.product-catalog-api.url=http://product-catalog-service:8080
quarkus.rest-client.customer-api.url=http://customer-service:8080
```

**No schema changes required** in Phase 2A - all services share existing database.

#### Step 1.4: Service Implementation - Product Catalog Service

**ProductSearchServiceImpl.java** (no changes from Phase 1):
```java
@ApplicationScoped
public class ProductSearchServiceImpl implements ProductSearchService {
    @Inject
    EntityManager em;
    
    public Product loadProduct(int productId) throws ProductDoesNotExistException {
        Product product = em.find(Product.class, productId);
        if(product == null) throw new ProductDoesNotExistException();
        return product;
    }
    
    public List<Product> loadProductsByCategory(int categoryId) {
        Query query = em.createNamedQuery("product.by.cat.or.sub");
        query.setParameter(1, categoryId);
        query.setParameter(2, categoryId);
        return query.getResultList();
    }
    
    public Category loadCategory(int categoryId) throws CategoryDoesNotExist {
        Category category = em.find(Category.class, categoryId);
        if(category == null) throw new CategoryDoesNotExist();
        return category;
    }
    
    public List<Category> getTopLevelCategories() {
        Query query = em.createNamedQuery("top.level.category");
        return query.getResultList();
    }
}
```

**ProductResource.java** (no changes from Phase 1)
**CategoryResource.java** (no changes from Phase 1)

**Endpoints:**
- GET /Product/{id}
- GET /Product?categoryId={id}
- GET /Category/{id}
- GET /Category

#### Step 1.5: Service Implementation - Customer Service

**Extract customer operations** from CustomerOrderServicesImpl:

**CustomerService.java** (NEW interface):
```java
public interface CustomerService {
    AbstractCustomer loadCustomer() throws CustomerDoesNotExistException;
    void updateAddress(Address address) throws CustomerDoesNotExistException;
    void updateInfo(HashMap<String, Object> info) throws CustomerDoesNotExistException;
}
```

**CustomerServiceImpl.java** (extracted from CustomerOrderServicesImpl):
```java
@ApplicationScoped
public class CustomerServiceImpl implements CustomerService {
    
    @Inject
    EntityManager em;
    
    @Inject
    SecurityIdentity securityIdentity;
    
    public AbstractCustomer loadCustomer() throws CustomerDoesNotExistException {
        String user = securityIdentity.getPrincipal().getName();
        Query query = em.createQuery("select c from AbstractCustomer c where c.user = :user");
        query.setParameter("user", user);
        return (AbstractCustomer)query.getSingleResult();
    }
    
    public void updateAddress(Address address) throws CustomerDoesNotExistException {
        AbstractCustomer customer = loadCustomer();
        customer.setAddress(address);
    }
    
    public void updateInfo(HashMap<String, Object> info) throws CustomerDoesNotExistException {
        AbstractCustomer customer = loadCustomer();
        if(info.get("type").equals("BUSINESS")) {
            ((BusinessCustomer)customer).setDescription((String)info.get("description"));
        } else {
            ((ResidentialCustomer)customer).setHouseholdSize(((Integer)info.get("householdSize")).shortValue());
        }
    }
}
```

**CustomerResource.java** (NEW):
```java
@Path("/Customer")
@RequestScoped
@RolesAllowed("SecureShopper")
public class CustomerResource {
    
    @Inject
    CustomerService customerService;
    
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response getCustomer() {
        try {
            AbstractCustomer customer = customerService.loadCustomer();
            return Response.ok(customer).build();
        } catch (CustomerDoesNotExistException e) {
            throw new WebApplicationException(Response.Status.NOT_FOUND);
        }
    }
    
    @PUT
    @Path("/Address")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response updateAddress(Address address) {
        try {
            customerService.updateAddress(address);
            return Response.noContent().build();
        } catch (CustomerDoesNotExistException e) {
            throw new WebApplicationException(Status.NOT_FOUND);
        }
    }
    
    @POST
    @Path("/Info")
    @Consumes(MediaType.APPLICATION_JSON)
    public Response updateInfo(HashMap<String, Object> info) {
        try {
            customerService.updateInfo(info);
            return Response.noContent().build();
        } catch (CustomerDoesNotExistException e) {
            throw new WebApplicationException(Status.NOT_FOUND);
        }
    }
}
```

**Endpoints:**
- GET /Customer
- PUT /Customer/Address
- POST /Customer/Info

#### Step 1.6: Service Implementation - Order Service

**Extract order operations** from CustomerOrderServicesImpl:

**OrderService.java** (NEW interface):
```java
public interface OrderService {
    Order addLineItem(LineItem lineItem) throws CustomerDoesNotExistException, 
        OrderNotOpenException, ProductDoesNotExistException, InvalidQuantityException, 
        OrderModifiedException;
    Order removeLineItem(int productId, long version) throws CustomerDoesNotExistException, 
        OrderNotOpenException, ProductDoesNotExistException, NoLineItemsException, 
        OrderModifiedException;
    void submit(long version) throws CustomerDoesNotExistException, OrderNotOpenException, 
        NoLineItemsException, OrderModifiedException;
    Set<Order> loadCustomerHistory() throws CustomerDoesNotExistException;
    Date getOrderHistoryLastUpdatedTime();
}
```

**OrderServiceImpl.java** (Phase 2A - with shared database):
```java
@ApplicationScoped
public class OrderServiceImpl implements OrderService {
    
    @Inject
    EntityManager em;
    
    @Inject
    SecurityIdentity securityIdentity;
    
    // Helper method to load customer from current user
    private AbstractCustomer loadCustomerFromDB() throws CustomerDoesNotExistException {
        String user = securityIdentity.getPrincipal().getName();
        Query query = em.createQuery("select c from AbstractCustomer c where c.user = :user");
        query.setParameter("user", user);
        return (AbstractCustomer)query.getSingleResult();
    }
    
    public Order addLineItem(LineItem newLineItem) 
            throws CustomerDoesNotExistException, OrderNotOpenException,
            ProductDoesNotExistException, InvalidQuantityException, OrderModifiedException {
        
        int productId = newLineItem.getProductId();
        long quantity = newLineItem.getQuantity();
        
        // Validate product exists (shared DB - direct query)
        Product product = em.find(Product.class, productId);
        if(quantity <= 0) throw new InvalidQuantityException();
        if(product == null) throw new ProductDoesNotExistException();
        
        // Load customer and their open order
        AbstractCustomer customer = loadCustomerFromDB();
        Order existingOpenOrder = customer.getOpenOrder();
        
        if(existingOpenOrder == null) {
            existingOpenOrder = openOrder(customer);
        } else {
            if(existingOpenOrder.getVersion() != newLineItem.getVersion()) {
                throw new OrderModifiedException();
            } else {
                existingOpenOrder.setVersion(newLineItem.getVersion());
            }
        }
        
        BigDecimal amount = product.getPrice().multiply(new BigDecimal(quantity));
        Set<LineItem> lineItems = existingOpenOrder.getLineitems();
        if (lineItems == null) lineItems = new HashSet<LineItem>();
        
        // Check if product already in cart
        for(LineItem lineItem : lineItems) {
            if(lineItem.getProductId() == productId) {
                lineItem.setQuantity(lineItem.getQuantity() + quantity);
                lineItem.setAmount(lineItem.getAmount().add(amount));
                return existingOpenOrder;
            }
        }
        
        // Add new line item
        LineItem lineItem = new LineItem();
        lineItem.setOrderId(existingOpenOrder.getOrderId());
        lineItem.setOrder(existingOpenOrder);
        lineItem.setProductId(product.getProductId());
        lineItem.setAmount(amount);
        lineItem.setProduct(product);
        lineItem.setQuantity(quantity);
        lineItems.add(lineItem);
        existingOpenOrder.setLineitems(lineItems);
        em.persist(lineItem);
        
        return existingOpenOrder;
    }
    
    private Order openOrder(AbstractCustomer customer) {
        Order newOrder = new Order();
        newOrder.setCustomer(customer);
        newOrder.setStatus(Order.Status.OPEN);
        newOrder.setTotal(new BigDecimal(0));
        em.persist(newOrder);
        customer.setOpenOrder(newOrder);
        return newOrder;
    }
    
    public Order removeLineItem(int productId, long version) 
            throws CustomerDoesNotExistException, OrderNotOpenException, 
            ProductDoesNotExistException, NoLineItemsException, OrderModifiedException {
        
        Product product = em.find(Product.class, productId);
        if(product == null) throw new ProductDoesNotExistException();
        
        AbstractCustomer customer = loadCustomerFromDB();
        Order existingOpenOrder = customer.getOpenOrder();
        
        if(existingOpenOrder == null || existingOpenOrder.getStatus() != Order.Status.OPEN) {
            throw new OrderNotOpenException();
        } else {
            if(existingOpenOrder.getVersion() != version) {
                throw new OrderModifiedException();
            } else {
                existingOpenOrder.setVersion(version);
            }
        }
        
        Set<LineItem> lineItems = existingOpenOrder.getLineitems();
        for(LineItem lineItem : lineItems) {
            if(lineItem.getProductId() == productId) {
                lineItems.remove(lineItem);
                existingOpenOrder.setLineitems(lineItems);
                em.remove(lineItem);
                return existingOpenOrder;
            }
        }
        throw new NoLineItemsException();
    }
    
    public void submit(long version) 
            throws CustomerDoesNotExistException, OrderNotOpenException, 
            NoLineItemsException, OrderModifiedException {
        
        AbstractCustomer customer = loadCustomerFromDB();
        Order existingOpenOrder = customer.getOpenOrder();
        
        if(existingOpenOrder == null || existingOpenOrder.getStatus() != Order.Status.OPEN) {
            throw new OrderNotOpenException();
        } else {
            if(existingOpenOrder.getVersion() != version) {
                throw new OrderModifiedException();
            } else {
                existingOpenOrder.setVersion(version);
            }
        }
        
        if(existingOpenOrder.getLineitems() == null || existingOpenOrder.getLineitems().size() <= 0) {
            throw new NoLineItemsException();
        }
        
        existingOpenOrder.setStatus(Order.Status.SUBMITTED);
        existingOpenOrder.setSubmittedTime(new Date());
        customer.setOpenOrder(null);
    }
    
    public Set<Order> loadCustomerHistory() throws CustomerDoesNotExistException {
        AbstractCustomer customer = loadCustomerFromDB();
        return customer.getOrders();
    }
    
    public Date getOrderHistoryLastUpdatedTime() {
        String user = securityIdentity.getPrincipal().getName();
        Query query = em.createQuery("select MAX(o.submittedTime) from Order o join o.customer c where c.user = :user");
        query.setParameter("user", user);
        return (Date)query.getSingleResult();
    }
}
```

**OrderResource.java** (adapted from CustomerOrderResource):
```java
@Path("/Orders")
@RequestScoped
@RolesAllowed("SecureShopper")
public class OrderResource {
    
    @Inject
    OrderService orderService;
    
    @POST
    @Path("/LineItem")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response addLineItem(LineItem lineItem, @Context HttpHeaders headers) {
        try {
            List<String> matchHeaders = headers.getRequestHeader("If-Match");
            if((matchHeaders != null) && (matchHeaders.size() > 0)) {
                lineItem.setVersion(new Long(matchHeaders.get(0)));
            }
            Order openOrder = orderService.addLineItem(lineItem);
            return Response.ok(openOrder).header("ETag", openOrder.getVersion()).build();
        } catch (CustomerDoesNotExistException e) {
            throw new WebApplicationException(Status.NOT_FOUND);
        } catch (ProductDoesNotExistException e) {
            throw new WebApplicationException(Status.NOT_FOUND);
        } catch (InvalidQuantityException e) {
            throw new WebApplicationException(Status.BAD_REQUEST);
        } catch (OrderModifiedException e) {
            throw new WebApplicationException(Status.PRECONDITION_FAILED);
        } catch (Exception e) {
            throw new WebApplicationException(e);
        }
    }
    
    @DELETE
    @Path("/LineItem/{productId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response removeLineItem(@PathParam("productId") int productId, @Context HttpHeaders headers) {
        try {
            List<String> matchHeaders = headers.getRequestHeader("If-Match");
            if((matchHeaders != null) && (matchHeaders.size() > 0)) {
                Order openOrder = orderService.removeLineItem(productId, new Long(matchHeaders.get(0)));
                return Response.ok(openOrder).header("ETag", openOrder.getVersion()).build();
            } else {
                return Response.status(Status.PRECONDITION_FAILED).build();
            }
        } catch (Exception e) {
            throw new WebApplicationException(e);
        }
    }
    
    @POST
    @Path("/Submit")
    public Response submitOrder(@Context HttpHeaders headers) {
        try {
            List<String> matchHeaders = headers.getRequestHeader("If-Match");
            if((matchHeaders != null) && (matchHeaders.size() > 0)) {
                orderService.submit(new Long(matchHeaders.get(0)));
                return Response.noContent().build();
            } else {
                return Response.status(Status.PRECONDITION_FAILED).build();
            }
        } catch (Exception e) {
            throw new WebApplicationException(e);
        }
    }
    
    @GET
    @Path("/History")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getOrderHistory(@Context HttpHeaders headers) {
        try {
            Date lastModified = orderService.getOrderHistoryLastUpdatedTime();
            List<String> matchHeaders = headers.getRequestHeader("If-Modified-Since");
            
            if((matchHeaders != null) && (matchHeaders.size() > 0)) {
                SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");
                Date headerDate = dateFormat.parse(matchHeaders.get(0));
                if(headerDate.getTime() < lastModified.getTime()) {
                    Set<Order> orders = orderService.loadCustomerHistory();
                    return Response.ok(orders).lastModified(lastModified).build();
                } else {
                    return Response.notModified().build();
                }
            } else {
                Set<Order> orders = orderService.loadCustomerHistory();
                return Response.ok(orders).lastModified(lastModified).build();
            }
        } catch (Exception e) {
            throw new WebApplicationException();
        }
    }
}
```

**Endpoints:**
- POST /Orders/LineItem
- DELETE /Orders/LineItem/{productId}
- POST /Orders/Submit
- GET /Orders/History

#### Step 1.7: API Gateway / URL Mapping

**Challenge**: Maintain existing API contracts while routing to different services

**Original URLs:**
```
/CustomerOrderServicesWeb/jaxrs/Product/{id}
/CustomerOrderServicesWeb/jaxrs/Category
/CustomerOrderServicesWeb/jaxrs/Customer
/CustomerOrderServicesWeb/jaxrs/Customer/OpenOrder/LineItem
/CustomerOrderServicesWeb/jaxrs/Customer/Orders
```

**New Service URLs:**
```
Product Catalog: /Product/{id}, /Category
Customer:        /Customer
Order:           /Orders/LineItem, /Orders/History
```

**Solution 1: API Gateway (Kong, Nginx, Traefik)**

**nginx.conf example:**
```nginx
upstream product_catalog {
    server product-catalog-service:8080;
}

upstream customer_service {
    server customer-service:8080;
}

upstream order_service {
    server order-service:8080;
}

server {
    listen 8080;
    
    location /CustomerOrderServicesWeb/jaxrs/Product {
        rewrite ^/CustomerOrderServicesWeb/jaxrs/Product(.*)$ /Product$1 break;
        proxy_pass http://product_catalog;
    }
    
    location /CustomerOrderServicesWeb/jaxrs/Category {
        rewrite ^/CustomerOrderServicesWeb/jaxrs/Category(.*)$ /Category$1 break;
        proxy_pass http://product_catalog;
    }
    
    location /CustomerOrderServicesWeb/jaxrs/Customer/OpenOrder {
        rewrite ^/CustomerOrderServicesWeb/jaxrs/Customer/OpenOrder(.*)$ /Orders$1 break;
        proxy_pass http://order_service;
    }
    
    location /CustomerOrderServicesWeb/jaxrs/Customer/Orders {
        rewrite ^/CustomerOrderServicesWeb/jaxrs/Customer/Orders(.*)$ /Orders/History$1 break;
        proxy_pass http://order_service;
    }
    
    location /CustomerOrderServicesWeb/jaxrs/Customer {
        rewrite ^/CustomerOrderServicesWeb/jaxrs/Customer(.*)$ /Customer$1 break;
        proxy_pass http://customer_service;
    }
}
```

**Solution 2: Update Service Paths**

Each service configures its root path to match existing API:

**product-catalog-service/application.properties:**
```properties
quarkus.http.root-path=/CustomerOrderServicesWeb
quarkus.resteasy.path=/jaxrs
```

**Result**: Less infrastructure, but services are coupled to legacy URL structure. Gateway approach preferred.

### Phase 2B: Inter-Service Communication (Weeks 3-4)

**Goal**: Replace direct database access with REST API calls

#### Step 2.1: Add REST Client to Order Service

**pom.xml (order-service):**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-rest-client-reactive-jackson</artifactId>
</dependency>
```

**ProductCatalogClient.java:**
```java
@Path("/Product")
@RegisterRestClient(configKey = "product-catalog-api")
public interface ProductCatalogClient {
    
    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    Product getProduct(@PathParam("id") int productId);
}
```

**application.properties (order-service):**
```properties
quarkus.rest-client.product-catalog-api.url=http://product-catalog-service:8080/CustomerOrderServicesWeb/jaxrs
quarkus.rest-client.product-catalog-api.scope=jakarta.inject.Singleton
```

#### Step 2.2: Update OrderServiceImpl

**Replace direct database query with REST call:**

```java
@ApplicationScoped
public class OrderServiceImpl implements OrderService {
    
    @Inject
    EntityManager em;
    
    @Inject
    SecurityIdentity securityIdentity;
    
    @Inject
    @RestClient
    ProductCatalogClient productClient;
    
    public Order addLineItem(LineItem newLineItem) 
            throws CustomerDoesNotExistException, OrderNotOpenException,
            ProductDoesNotExistException, InvalidQuantityException, OrderModifiedException {
        
        int productId = newLineItem.getProductId();
        long quantity = newLineItem.getQuantity();
        
        // CHANGED: Call Product Catalog Service instead of direct DB query
        Product product;
        try {
            product = productClient.getProduct(productId);
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                throw new ProductDoesNotExistException();
            }
            throw e;
        }
        
        if(quantity <= 0) throw new InvalidQuantityException();
        
        // Rest of the method remains the same...
        AbstractCustomer customer = loadCustomerFromDB();
        Order existingOpenOrder = customer.getOpenOrder();
        // ... (continue as before)
    }
}
```

**Remove Product entity** from order-service (no longer needed for validation).

#### Step 2.3: Resilience Patterns

**Add circuit breaker and fallback:**

**pom.xml (order-service):**
```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-smallrye-fault-tolerance</artifactId>
</dependency>
```

**Enhanced ProductCatalogClient:**
```java
@Path("/Product")
@RegisterRestClient(configKey = "product-catalog-api")
public interface ProductCatalogClient {
    
    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    @Retry(maxRetries = 3, delay = 100, delayUnit = ChronoUnit.MILLIS)
    @CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5, delay = 5000)
    @Fallback(fallbackMethod = "getProductFallback")
    Product getProduct(@PathParam("id") int productId);
    
    default Product getProductFallback(int productId) {
        // Option 1: Return cached product if available
        // Option 2: Throw service unavailable exception
        throw new WebApplicationException("Product Catalog Service unavailable", 503);
    }
}
```

**Trade-offs:**
- **Circuit breaker**: Prevents cascading failures, but may reject valid requests
- **Retry**: Improves resilience against transient failures, but increases latency
- **Fallback**: Graceful degradation, but may provide stale data

### Phase 2C: Database Separation (Weeks 5-6)

**Goal**: Move from shared database to database-per-service

#### Strategy: Gradual Schema Split

**Option A: Separate PostgreSQL Databases**
```
postgres-productcatalog-db (product, category, prod_cat tables)
postgres-customer-db (customer table)
postgres-order-db (orders, line_item tables)
```

**Option B: Separate Schemas in Same Database**
```
ORDERDB.product_catalog (product, category, prod_cat)
ORDERDB.customer (customer)
ORDERDB.orders (orders, line_item)
```

**Recommendation**: Option B (separate schemas) for Phase 2C, Option A (separate databases) for Phase 3.

#### Step 3.1: Schema Migration Script

**Create schemas:**
```sql
-- Create separate schemas
CREATE SCHEMA product_catalog;
CREATE SCHEMA customer_schema;
CREATE SCHEMA order_schema;

-- Move tables to schemas
ALTER TABLE product SET SCHEMA product_catalog;
ALTER TABLE category SET SCHEMA product_catalog;
ALTER TABLE prod_cat SET SCHEMA product_catalog;

ALTER TABLE customer SET SCHEMA customer_schema;

ALTER TABLE orders SET SCHEMA order_schema;
ALTER TABLE line_item SET SCHEMA order_schema;
```

**Update service configurations:**

**product-catalog-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB?currentSchema=product_catalog
```

**customer-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB?currentSchema=customer_schema
```

**order-service/application.properties:**
```properties
quarkus.datasource.jdbc.url=jdbc:postgresql://postgres-orderdb:5432/ORDERDB?currentSchema=order_schema
```

#### Step 3.2: Handling Cross-Schema References

**Problem**: Order table has foreign key to Customer table (CUSTOMER_ID)

**Solution Options:**

**Option 1: Remove Foreign Key Constraint**
```sql
ALTER TABLE order_schema.orders DROP CONSTRAINT IF EXISTS fk_customer;
```
- **Pros**: Services are decoupled at database level
- **Cons**: Referential integrity must be enforced by application

**Option 2: Keep Foreign Key with Cross-Schema Reference**
```sql
-- Maintain FK but across schemas
ALTER TABLE order_schema.orders 
  ADD CONSTRAINT fk_customer 
  FOREIGN KEY (customer_id) 
  REFERENCES customer_schema.customer(customer_id);
```
- **Pros**: Database maintains integrity
- **Cons**: Database coupling remains

**Recommendation**: Option 1 for true microservices independence. Application must validate customer exists before creating orders.

#### Step 3.3: Customer Validation in Order Service

**OrderServiceImpl - validate customer exists:**

```java
@ApplicationScoped
public class OrderServiceImpl implements OrderService {
    
    @Inject
    @RestClient
    CustomerClient customerClient;
    
    @Inject
    @RestClient
    ProductCatalogClient productClient;
    
    public Order addLineItem(LineItem newLineItem) 
            throws CustomerDoesNotExistException, ... {
        
        // Validate customer exists via REST call
        try {
            Customer customer = customerClient.getCustomer();
            int customerId = customer.getCustomerId();
            
            // Validate product exists
            Product product = productClient.getProduct(newLineItem.getProductId());
            
            // Continue with order logic...
            // Store customerId with order (no longer using Customer entity)
        } catch (WebApplicationException e) {
            if (e.getResponse().getStatus() == 404) {
                throw new CustomerDoesNotExistException();
            }
            throw e;
        }
    }
}
```

**Order entity update - remove Customer relationship:**

```java
@Entity
@Table(name="orders", schema="order_schema")
public class Order implements Serializable {
    
    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    @Column(name="ORDER_ID")
    protected int orderId;
    
    // CHANGED: Remove ManyToOne relationship, just store customer ID
    @Column(name="CUSTOMER_ID")
    protected int customerId;
    
    // ... rest of fields unchanged
}
```

**Trade-off**: Loss of JPA relationship navigation (customer.getOrders()). Must be replaced with service calls.

### Phase 2D: Testing and Validation (Week 6)

#### Integration Testing Strategy

**Test Scenarios:**

1. **Product Catalog Service (Isolated)**
   - GET /Product/{id} returns product
   - GET /Category returns categories
   - Service handles database unavailability

2. **Customer Service (Isolated)**
   - GET /Customer returns customer for authenticated user
   - PUT /Customer/Address updates address
   - Security enforces authentication

3. **Order Service (With Dependencies)**
   - POST /Orders/LineItem validates product exists (calls Product Catalog)
   - POST /Orders/LineItem validates customer exists (calls Customer Service)
   - Circuit breaker activates when Product Catalog unavailable
   - Optimistic locking works correctly

4. **End-to-End Workflow**
   - Browse products → Add to cart → Update cart → Submit order → View history
   - All services must be running
   - API gateway routes correctly

**Test Tools:**
- Quarkus Dev Services (automatic test containers)
- WireMock (mock external service calls)
- TestContainers (integration test with real PostgreSQL)
- REST Assured (API testing)

**Example integration test:**

```java
@QuarkusTest
public class OrderServiceIntegrationTest {
    
    @InjectMock
    @RestClient
    ProductCatalogClient productClient;
    
    @InjectMock
    @RestClient
    CustomerClient customerClient;
    
    @Test
    @TestSecurity(user = "rbarcia", roles = "SecureShopper")
    public void testAddLineItemWithServiceCalls() {
        // Mock Product Catalog response
        Product mockProduct = new Product();
        mockProduct.setProductId(1);
        mockProduct.setPrice(new BigDecimal("19.99"));
        Mockito.when(productClient.getProduct(1)).thenReturn(mockProduct);
        
        // Mock Customer Service response
        Customer mockCustomer = new Customer();
        mockCustomer.setCustomerId(1001);
        Mockito.when(customerClient.getCustomer()).thenReturn(mockCustomer);
        
        // Test adding line item
        LineItem lineItem = new LineItem();
        lineItem.setProductId(1);
        lineItem.setQuantity(2);
        
        given()
          .contentType("application/json")
          .body(lineItem)
          .when().post("/Orders/LineItem")
          .then()
             .statusCode(200)
             .body("lineitems[0].quantity", is(2));
        
        // Verify service calls were made
        Mockito.verify(productClient).getProduct(1);
        Mockito.verify(customerClient).getCustomer();
    }
}
```

### Phase 2 Rollback Strategy

**Rollback Points:**

1. **After Phase 2A (Shared Database)**: Revert to Phase 1 Quarkus monolith
2. **After Phase 2B (REST Calls)**: Revert to Phase 2A (direct DB access)
3. **After Phase 2C (Schema Split)**: Merge schemas back, revert to Phase 2B

**Rollback Procedure:**
1. Route traffic to previous version (blue/green deployment)
2. Database rollback (restore from backup if schema changes applied)
3. Investigate issues offline
4. Fix and redeploy incrementally

**Rollback Triggers:**
- Latency increase >50ms (due to inter-service calls)
- Availability <99.9% (service dependencies causing failures)
- Data inconsistency (distributed transaction issues)
- Security vulnerabilities

---

## PHASE 3: Production Hardening (Optional - 2-3 weeks)

### Enhancements to Consider

1. **Observability**
   - Distributed tracing (Jaeger, OpenTelemetry)
   - Centralized logging (ELK stack)
   - Metrics (Prometheus, Grafana)

2. **Event-Driven Architecture**
   - Replace synchronous REST calls with Kafka/RabbitMQ
   - Implement CQRS for order history
   - Event sourcing for order state changes

3. **Advanced Resilience**
   - Service mesh (Istio, Linkerd)
   - Rate limiting
   - Advanced circuit breaker patterns

4. **Database Evolution**
   - Separate PostgreSQL instances per service
   - Read replicas for product catalog
   - Caching layer (Redis) for frequently accessed data

5. **Security Enhancements**
   - OAuth2/OIDC (replace BASIC auth)
   - JWT tokens for inter-service communication
   - Secret management (Vault)

6. **Performance Optimization**
   - Native compilation (GraalVM)
   - Response caching
   - Database query optimization

---

## Deployment Strategy

### Kubernetes Deployment

**Namespace Structure:**
```
customer-order-services/
├── product-catalog-deployment.yaml
├── customer-deployment.yaml
├── order-deployment.yaml
├── postgres-statefulset.yaml
├── api-gateway-deployment.yaml (nginx)
└── ingress.yaml
```

**Example Deployment (Order Service):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: customer-order-services
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: order-service:0.1.0
        ports:
        - containerPort: 8080
        env:
        - name: QUARKUS_DATASOURCE_JDBC_URL
          value: "jdbc:postgresql://postgres-orderdb:5432/ORDERDB?currentSchema=order_schema"
        - name: QUARKUS_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: QUARKUS_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: QUARKUS_REST_CLIENT_PRODUCT_CATALOG_API_URL
          value: "http://product-catalog-service:8080"
        - name: QUARKUS_REST_CLIENT_CUSTOMER_API_URL
          value: "http://customer-service:8080"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: customer-order-services
spec:
  selector:
    app: order-service
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
```

### CI/CD Pipeline

**Build Pipeline:**
```yaml
# .github/workflows/build.yml
name: Build Microservices
on: [push]
jobs:
  build-product-catalog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up JDK 17
        uses: actions/setup-java@v2
        with:
          java-version: '17'
      - name: Build with Maven
        run: cd product-catalog-service && mvn clean package
      - name: Build Docker image
        run: docker build -f product-catalog-service/src/main/docker/Dockerfile.jvm -t product-catalog-service:latest .
      # ... push to registry
  
  build-customer:
    # ... similar steps
  
  build-order:
    # ... similar steps
```

**Deployment Strategy: Blue/Green**
```
Blue (current):  v1.0 (Phase 1 - Quarkus monolith)
Green (new):     v2.0 (Phase 2 - Microservices)

Traffic: 100% → Blue
Test Green deployment
Gradually shift traffic: 10% → 50% → 100% to Green
Keep Blue running for 24-48 hours
Decommission Blue after validation
```

---

## Risk Assessment and Mitigation

### High-Risk Areas

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| **Distributed transaction failure** | High | Medium | Use saga pattern, implement compensation logic, eventual consistency |
| **Service dependency failures** | High | Medium | Circuit breakers, retries, fallbacks, health checks |
| **Data consistency issues** | High | Low | Thorough testing, optimistic locking, versioning |
| **Performance degradation** | Medium | Medium | Load testing, caching, monitoring, SLAs |
| **Security vulnerabilities** | High | Low | Security reviews, penetration testing, OAuth2 |
| **Increased operational complexity** | Medium | High | Automation, observability, runbooks, training |

### Key Dependencies Between Phases

**Phase 1 → Phase 2:**
- Quarkus migration must be stable before microservices split
- Security context replacement (SessionContext → SecurityIdentity) must work correctly
- All REST endpoints must maintain contracts

**Phase 2A → Phase 2B:**
- Shared database must remain stable during REST client introduction
- REST client configuration must be tested thoroughly
- Rollback path must be validated

**Phase 2B → Phase 2C:**
- Inter-service communication must be working reliably
- Database schema migration must be reversible
- Foreign key removal must not cause data integrity issues

---

## Success Criteria

### Phase 1 Success Metrics
- All existing API tests pass
- Startup time < 3 seconds (JVM mode)
- Memory usage < 150MB (idle)
- Zero regression in functionality
- Security works correctly (BASIC auth, role-based access)

### Phase 2 Success Metrics
- Three independent services deployed
- API gateway routes correctly
- Inter-service communication latency < 50ms (p95)
- No data loss during migration
- Rollback capability verified
- Circuit breakers prevent cascading failures

### Phase 3 Success Metrics (Optional)
- Distributed tracing shows complete request path
- Service mesh provides automatic retries and load balancing
- Native builds reduce memory by 50%
- Event-driven patterns reduce coupling

---

## Critical Files for Implementation

### Phase 1: Quarkus Migration
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/service/ProductSearchServiceImpl.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/service/CustomerOrderServicesImpl.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServicesWeb/src/org/pwte/example/resources/CustomerOrderResource.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServicesProject/pom.xml
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/META-INF/persistence.xml

### Phase 2: Microservices Decomposition
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/domain/Product.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/domain/Order.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/domain/AbstractCustomer.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/CustomerOrderServices/ejbModule/org/pwte/example/domain/LineItem.java
- /Users/ddesilva/Developer/projects/refarch-jee-jakarta/Common/createOrderDB_postgres.sql
